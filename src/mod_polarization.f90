#include "f_cart_components.h"
module mod_polarization
    !! Module to handle the calculation of the induced dipoles; this means find
    !! the solution of the polarization problem. The polarization problem is 
    !! defined by the linear system 
    !! \begin{equation}
    !!    \mathbf{T}\mathbf{\mu} = \mathbf{E},
    !!    \label{eq:pol_ls}
    !! \end{equation}
    !! where \(\mathbf E\) is the 'external' (here external means the sum of the
    !! electric field generated by QM density and the one generated by the MM
    !! sites) electric field at induced dipole sites, \(\mathbf{\mu}\) are the 
    !! induced dipoles - the solution of the linear system -, and \(\mathbf{T}\)
    !! is the interaction tensor between the induced point dipoles.
    !!
    !! Linear system \eqref{eq:pol_ls} can be solved with different methods 
    !! (see [[mod_solvers]] for further details). Some of them requires to 
    !! explicitly build \(\mathbf{T}\) in memory (eg. 
    !! [[mod_solvers::inversion_solver]]), while other only requires to
    !! perform matrix-vector multiplication without building explicitly the
    !! interaction tensor.
    !! Interaction tensor is conveniently tought as a square matrix of dimension
    !! number of induced dipoles, of rank 3 tensors expressing the interaction
    !! between the two elements. We can distinguish the case of diagonal 
    !! elements:
    !! \begin{equation}
    !!    \mathbf T_{ii} = \frac{1}{\alpha_i} \mathbf I_3,
    !!    \label{eq:T_diag}
    !! \end{equation}
    !! and the off-diagonal elements:
    !! \begin{equation}
    !!    \mathbf T_{ij} = ...
    !!    \label{eq:T_offdiag}
    !! \end{equation}

    use mod_memory, only: ip, rp
    use mod_io, only: ommp_message, fatal_error
    use mod_mmpol, only: ommp_system 
    use mod_electrostatics, only: ommp_electrostatics_type

    implicit none 
    private
    

    public :: polarization, polarization_terminate
    
    contains
    
    subroutine polarization(sys_obj, e, & 
                            & arg_solver, arg_mvmethod, arg_ipd_mask)
        !! Main driver for the calculation of induced dipoles. 
        !! Takes electric field at induced dipole sites as input and -- if
        !! solver converges -- provides induced dipoles as output.
        !! Since AMOEBA requires the calculations of two sets of induced dipoles
        !! generated from two different electric fields (normally called direct (D) 
        !! and polarization (P)) both electric field and induced dipoles are shaped
        !! with an extra dimension and this routine calls the solver twice to 
        !! solve the two linear systems in the case of AMOEBA FF. Direct electric
        !! field and induced dipoles are stored in e(:,:,1)/ipds(:,:,1) while
        !! polarization field/dipole are stored in e(:,:,2)/ipds(:,:,2).

        use mod_solvers, only: jacobi_diis_solver, conjugate_gradient_solver, &
                               inversion_solver
        use mod_memory, only: ip, rp, mallocate, mfree
        use mod_io, only: print_matrix, time_pull, time_push
        use mod_constants, only: OMMP_MATV_DEFAULT, &
                                 OMMP_MATV_DIRECT, &
                                 OMMP_MATV_INCORE, &
                                 OMMP_MATV_NONE, &
                                 OMMP_SOLVER_DEFAULT, &
                                 OMMP_SOLVER_CG, &
                                 OMMP_SOLVER_DIIS, &
                                 OMMP_SOLVER_INVERSION, &
                                 OMMP_SOLVER_NONE, &
                                 OMMP_VERBOSE_DEBUG, &
                                 OMMP_VERBOSE_HIGH, &
                                 eps_rp
      
        implicit none

        type(ommp_system), target, intent(inout) :: sys_obj
        !! Fundamental data structure for OMMP system
        real(rp), dimension(3, sys_obj%eel%pol_atoms, sys_obj%eel%n_ipd), &
        & intent(in) :: e
        !! Total electric field that induces the dipoles

        integer(ip), intent(in), optional :: arg_solver
        !! Flag for the solver to be used; optional, should be one OMMP_SOLVER_
        !! if not provided [[mod_constants:OMMP_SOLVER_DEFAULT]] is used.
        integer(ip), intent(in), optional :: arg_mvmethod
        !! Flag for the matrix-vector method to be used; optional, should be one of
        !! OMMP_MATV_ if not provided [[mod_constants:OMMP_MATV_DEFAULT]] is used.
        logical, intent(in), optional :: arg_ipd_mask(sys_obj%eel%n_ipd)
        !! Logical mask to skip calculation of one of the two set of dipoles
        !! in AMOEBA calculations (eg. when MM part's field is not taken into
        !! account, both P and D field are just external field, so there is no
        !! reason to compute it twice). If n_ipd == 1 this is always considered
        !! true.
        
        real(rp), dimension(:, :), allocatable :: e_vec, ipd0
        real(rp), dimension(:), allocatable :: inv_diag
        integer(ip) :: i, n, solver, mvmethod
        logical :: ipd_mask(sys_obj%eel%n_ipd), amoeba
        type(ommp_electrostatics_type), pointer :: eel

        abstract interface
        subroutine mv(eel, x, y, dodiag)
                use mod_memory, only: rp, ip
                use mod_electrostatics, only : ommp_electrostatics_type
                type(ommp_electrostatics_type), intent(in) :: eel
                real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
                real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
                logical, intent(in) :: dodiag
            end subroutine mv
        end interface
        procedure(mv), pointer :: matvec
        
        abstract interface
        subroutine pc(eel, x, y)
                use mod_memory, only: rp, ip
                use mod_electrostatics, only : ommp_electrostatics_type
                type(ommp_electrostatics_type), intent(in) :: eel
                real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
                real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
            end subroutine pc
        end interface
        procedure(pc), pointer :: precond
        
        call time_push()
        ! Shortcuts
        eel => sys_obj%eel
        amoeba = sys_obj%amoeba

        ! Defaults for safety
        matvec => TMatVec_incore
        precond => PolVec

        if(eel%pol_atoms == 0) then
            ! If the system is not polarizable, there is nothing to do.
            return
        end if

        ! Handling of optional arguments
        if(present(arg_solver)) then
            solver = arg_solver
            if(solver == OMMP_SOLVER_NONE) solver = eel%def_solver
        else
            solver = eel%def_solver
        end if

        if(present(arg_mvmethod)) then
            mvmethod = arg_mvmethod
            if(mvmethod == OMMP_MATV_NONE) mvmethod = eel%def_matv
        else
            mvmethod = eel%def_matv
        end if

        if(present(arg_ipd_mask) .and. eel%n_ipd > 1) then
            ipd_mask = arg_ipd_mask
        else
            ipd_mask = .true.
        end if

        ! Dimension of the system
        n = 3*eel%pol_atoms

        call mallocate('polarization [ipd0]', n, eel%n_ipd, ipd0)
        call mallocate('polarization [e_vec]', n, eel%n_ipd, e_vec)

        ! Allocate and compute dipole polarization tensor, if needed
        if(mvmethod == OMMP_MATV_INCORE .or. &
           solver == OMMP_SOLVER_INVERSION) then
            if(.not. allocated(eel%tmat)) then !TODO move this in create_tmat
                call ommp_message("Allocating T matrix.", OMMP_VERBOSE_DEBUG)
                call mallocate('polarization [TMat]',n,n,eel%tmat)
                call create_TMat(eel)
            end if
        end if

        ! Reshape electric field matrix into a vector
        ! direct field for Wang and Amoeba
        ! polarization field just for Amoeba
        if(amoeba) then
            if(ipd_mask(_amoeba_D_)) &
                e_vec(:, _amoeba_D_) = reshape(e(:,:,_amoeba_D_), (/ n /))
            if(ipd_mask(_amoeba_P_)) &
                e_vec(:, _amoeba_P_) = reshape(e(:,:,_amoeba_P_), (/ n /))
        else
            e_vec(:, 1) = reshape(e(:,:, 1), (/ n /))
        end if
        
        ! Initialization of dipoles
        ipd0 = 0.0_rp
        if(solver /= OMMP_SOLVER_INVERSION) then
            ! Create a guess for dipoles
            if(eel%ipd_use_guess) then
                if(amoeba) then
                    if(ipd_mask(_amoeba_D_)) then
                        ipd0(:,_amoeba_D_) = &
                            reshape(eel%ipd(:,:,_amoeba_D_), [n])
                    end if
                    if(ipd_mask(_amoeba_P_)) then
                       ipd0(:, _amoeba_P_) = &
                           reshape(eel%ipd(:,:,_amoeba_P_), [n])
                    end if
                else
                    ! call PolVec(eel, e_vec(:,1), ipd0(:,1))
                    ipd0(:, 1) = &
                        reshape(eel%ipd(:,:,1), [n])
                end if
            end if

            select case(mvmethod)
                case(OMMP_MATV_INCORE) 
                    call ommp_message("Matrix-Vector will be performed in-memory", &
                                 OMMP_VERBOSE_HIGH)
                    matvec => TMatVec_incore

                case(OMMP_MATV_DIRECT)
                    call ommp_message("Matrix-Vector will be performed on-the-fly", &
                                 OMMP_VERBOSE_HIGH)
                    matvec => TMatVec_otf

                case default
                    call fatal_error("Unknown matrix-vector method requested")
            end select
        end if
        select case (solver)
            case(OMMP_SOLVER_CG)
                ! For now we do not have any other option.
                precond => PolVec

                if(amoeba) then
                    if(ipd_mask(_amoeba_D_)) &
                        call conjugate_gradient_solver(n, &
                                                       e_vec(:,_amoeba_D_), &
                                                       ipd0(:,_amoeba_D_), &
                                                       eel, matvec, precond)
                    ! If both sets have to be computed and there is no input
                    ! guess, just use D as guess for P, not a big gain but still
                    ! something
                    if(ipd_mask(_amoeba_D_) .and. ipd_mask(_amoeba_P_) &
                       .and. .not. eel%ipd_use_guess) &
                        ipd0(:,_amoeba_P_) = ipd0(:,_amoeba_D_)
                    if(ipd_mask(_amoeba_P_)) &
                        call conjugate_gradient_solver(n, &
                                                       e_vec(:,_amoeba_P_), &
                                                       ipd0(:,_amoeba_P_), &
                                                       eel, matvec, precond)
                else
                    call conjugate_gradient_solver(n, e_vec(:,1), ipd0(:,1), &
                                                   eel, matvec, precond)
                end if

            case(OMMP_SOLVER_DIIS)
                ! Create a vector containing inverse of diagonal of T matrix
                call mallocate('polarization [inv_diag]', n, inv_diag)

                !$omp parallel do default(shared) private(i) schedule(static)
                do i=1, eel%pol_atoms
                    inv_diag(3*(i-1)+1:3*(i-1)+3) = eel%pol(i) 
                end do

                if(amoeba) then
                    if(ipd_mask(_amoeba_D_)) &
                        call jacobi_diis_solver(n, &
                                                e_vec(:,_amoeba_D_), &
                                                ipd0(:,_amoeba_D_), &
                                                eel, matvec, inv_diag)
                    ! If both sets have to be computed and there is no input
                    ! guess, just use D as guess for P, not a big gain but still
                    ! something
                    if(ipd_mask(_amoeba_D_) .and. ipd_mask(_amoeba_P_) &
                       .and. .not. eel%ipd_use_guess) &
                        ipd0(:,_amoeba_P_) = ipd0(:,_amoeba_D_)
                    if(ipd_mask(_amoeba_P_)) &
                        call jacobi_diis_solver(n, &
                                                e_vec(:,_amoeba_P_), &
                                                ipd0(:,_amoeba_P_), &
                                                eel, matvec, inv_diag)
                else
                    call jacobi_diis_solver(n, e_vec(:,1), ipd0(:,1), &
                                            eel, matvec, inv_diag)
                end if
                call mfree('polarization [inv_diag]', inv_diag)

            case(OMMP_SOLVER_INVERSION)
                if(amoeba) then
                    if(ipd_mask(_amoeba_D_)) &
                        call inversion_solver(n, &
                                              e_vec(:,_amoeba_D_), &
                                              ipd0(:,_amoeba_D_), eel%TMat)
                    if(ipd_mask(_amoeba_P_)) &
                        call inversion_solver(n, &
                                              e_vec(:,_amoeba_P_), &
                                              ipd0(:,_amoeba_P_), eel%TMat)
                else
                    call inversion_solver(n, e_vec(:,1), ipd0(:,1), eel%TMat)
                end if
                
            case default
                call fatal_error("Unknown solver for calculation of the induced point dipoles") 
        end select
        
        ! Reshape dipole vector into the matrix 
        eel%ipd = reshape(ipd0, (/3_ip, eel%pol_atoms, eel%n_ipd/)) 
        eel%ipd_done = .true. !! TODO Maybe check convergence...
        eel%ipd_use_guess = .true.
        
        call mfree('polarization [ipd0]', ipd0)
        call mfree('polarization [e_vec]', e_vec)
        call time_pull('Polarization routine')

    end subroutine polarization

    subroutine polarization_terminate(eel)
        use mod_memory, only: mfree 

        implicit none

        type(ommp_electrostatics_type), intent(inout) :: eel
        
        if(allocated(eel%TMat)) &
            call mfree('polarization [TMat]', eel%TMat)

    end subroutine polarization_terminate
    
    subroutine dipole_T(eel, i, j, tens)
        !! This subroutine compute the interaction tensor (rank 3) between
        !! two polarizable sites i and j.
        !! This tensor is built according to the following rules: ... TODO
        use mod_electrostatics, only: screening_rules, damped_coulomb_kernel

        implicit none
        !                      
        ! Compute element of the polarization tensor TTens between
        ! polarizable cpol atom I and polarizable cpol atom J. On the
        ! TTens diagonal (I=J) are inverse polarizabilities and on the 
        ! off-diagonal dipole field.
        !
        ! Polarizabilities pol are defined for polarizable atoms only while 
        ! Thole factors are defined for all of them
        
        type(ommp_electrostatics_type), intent(inout) :: eel
        !! The electostatic data structure  for which the 
        !! interaction tensor should be computed
        integer(ip), intent(in) :: i 
        !! Index (in the list of polarizable sites) of the source site
        integer(ip), intent(in) :: j
        !! Index (in the list of polarizable sites) of the target site
        real(rp), dimension(3, 3), intent(out) :: tens
        !! Interaction tensor between sites i and j
        
        real(rp) :: dr(3)
        real(rp) ::  kernel(3), scalf
        logical :: to_do, to_scale

        integer(ip) :: ii, jj
         
        tens = 0.0_rp
        
        if(i == j) then
            tens(1, 1) = 1.0_rp / eel%pol(i)
            tens(2, 2) = 1.0_rp / eel%pol(i)
            tens(3, 3) = 1.0_rp / eel%pol(i)
        else
            call screening_rules(eel, i, 'P', j, 'P', '-', &
                                 to_do, to_scale, scalf)
            if(to_do) then
                call damped_coulomb_kernel(eel, eel%polar_mm(i), &
                                           eel%polar_mm(j), 2, kernel, dr)
                ! Fill the matrix elemets
                do ii=1, 3
                    do jj=1, 3
                        if(ii == jj) then
                            tens(ii, ii) = kernel(2) - 3.0_rp * kernel(3) * dr(ii) ** 2
                        else
                            tens(jj, ii) = -3.0_rp * kernel(3) * dr(ii) * dr(jj)
                        end if
                    end do
                end do
                ! Scale if needed
                if(to_scale) tens = tens * scalf
            
            end if
        end if
    end subroutine dipole_T
        
    subroutine create_tmat(eel)
        !! Explicitly construct polarization tensor in memory. This routine
        !! is only used to accumulate results from [[dipole_T]] and shape it in
        !! the correct way.

        use mod_io, only: print_matrix
        use mod_constants, only: OMMP_VERBOSE_HIGH

        implicit none
        
        type(ommp_electrostatics_type), intent(inout) :: eel
        !! The electostatic data structure  for which the 
        !! interaction tensor should be computed
        real(rp), dimension(3, 3) :: tensor
        !! Temporary interaction tensor between two sites

        integer(ip) :: i, j, ii, jj
        
        call ommp_message("Explicitly computing interaction matrix to solve &
                           &the polarization system", OMMP_VERBOSE_HIGH)

        ! Initialize the tensor with zeros
        eel%tmat = 0.0_rp
        
        !$omp parallel do default(shared) schedule(dynamic) &
        !$omp private(i,j,tensor,ii,jj) 
        do i = 1, eel%pol_atoms
            do j = 1, i
                call dipole_T(eel, i, j, tensor)
                
                do ii=1, 3
                    do jj=1, 3
                        eel%tmat((j-1)*3+jj, (i-1)*3+ii) = tensor(jj, ii)
                        eel%tmat((i-1)*3+ii, (j-1)*3+jj) = tensor(jj, ii)
                    end do
                end do
            enddo
        enddo
        
        ! Print the matrix if verbose output is requested
        ! if(verbose == OMMP_VERBOSE_DEBUG) then
        !     call print_matrix(.true., 'Polarization tensor:', &
        !                       3*pol_atoms, 3*pol_atoms, &
        !                       3*pol_atoms, 3*pol_atoms, TMat)
        ! end if
        
    end subroutine create_TMat

    subroutine TMatVec_incore(eel, x, y, dodiag)
        !! Perform matrix vector multiplication y = TMat*x,
        !! where TMat is polarization matrix (precomputed and stored in memory)
        !! and x and y are column vectors
        
        implicit none
        
        type(ommp_electrostatics_type), intent(in) :: eel
        !! The electostatic data structure 
        real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
        !! Input vector
        real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
        !! Output vector
        logical, intent(in) :: dodiag
        !! Logical flag (.true. = diagonal is computed, .false. = diagonal is
        !! skipped)
        
        call TMatVec_offdiag(eel, x, y)
        if(dodiag) call TMatVec_diag(eel, x, y)
    
    end subroutine TMatVec_incore
    
    subroutine TMatVec_otf(eel, x, y, dodiag)
        !! Perform matrix vector multiplication y = TMat*x,
        !! where TMat is polarization matrix (precomputed and stored in memory)
        !! and x and y are column vectors
        use mod_electrostatics, only: field_extD2D
        implicit none
        
        type(ommp_electrostatics_type), intent(in) :: eel
        !! The electostatic data structure 
        real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
        !! Input vector
        real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
        !! Output vector
        logical, intent(in) :: dodiag
        !! Logical flag (.true. = diagonal is computed, .false. = diagonal is
        !! skipped)
        
        y = 0.0_rp
        call field_extD2D(eel, x, y)
        y = -1.0_rp * y ! Why? TODO
        if(dodiag) call TMatVec_diag(eel, x, y)
    
    end subroutine TMatVec_otf
       
    subroutine TMatVec_diag(eel, x, y)
        !! This routine compute the product between the diagonal of T matrix
        !! with x, and add it to y. The product is simply computed by 
        !! each element of x for its inverse polarizability.

        implicit none

        type(ommp_electrostatics_type), intent(in) :: eel
        !! The electostatic data structure 
        real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
        !! Input vector
        real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
        !! Output vector

        integer(ip) :: i, ii

        !$omp parallel do default(shared) private(i,ii) 
        do i=1, 3*eel%pol_atoms
            ii = (i+2)/3
            y(i) = y(i) + x(i) / eel%pol(ii)
        end do
    end subroutine TMatVec_diag

    subroutine TMatVec_offdiag(eel, x, y)
        !! Perform matrix vector multiplication y = [TMat-diag(TMat)]*x,
        !! where TMat is polarization matrix (precomputed and stored in memory)
        !! and x and y are column vectors 
        use mod_memory, only: mallocate, mfree
        
        implicit none
        
        type(ommp_electrostatics_type), intent(in) :: eel
        !! The electostatic data structure 
        real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
        !! Input vector
        real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
        !! Output vector
        
        integer(ip) :: i, n

        n = 3*eel%pol_atoms
       
        ! Compute the matrix vector product
        call dgemm('N', 'N', n, 1, n, 1.0_rp, eel%tmat, n, x, n, 0.0_rp, y, n)
        ! Subtract the product of diagonal 
        !$omp parallel do default(shared) private(i) 
        do i = 1, n
            y(i) = y(i) - eel%tmat(i,i) * x(i)
        end do
    
    end subroutine TMatVec_offdiag

    subroutine PolVec(eel, x, y)
        !! Perform matrix vector multiplication y = pol*x,
        !! where pol is polarizability vector, x and y are 
        !! column vectors
        
        implicit none
        
        type(ommp_electrostatics_type), intent(in) :: eel
        !! The electostatic data structure 
        real(rp), dimension(3*eel%pol_atoms), intent(in) :: x
        !! Input vector
        real(rp), dimension(3*eel%pol_atoms), intent(out) :: y
        !! Output vector
        
        integer(ip) :: i, indx
        
        !$omp parallel do default(shared) private(indx,i)
        do i = 1, 3*eel%pol_atoms
            indx = (i+2)/3
            y(i) = eel%pol(indx)*x(i)   
        enddo
        
    end subroutine PolVec

end module mod_polarization
