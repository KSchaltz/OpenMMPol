module mod_mmpol
    !! Main module for the control of openMMPol library. It contains
    !! all the scalar and vector (allocatable) quantities needed to
    !! build up the atomistic polarizable embedding model and perform
    !! the calculation required from the quantum chemical software.
    
    use mod_memory, only: ip, rp
    use mod_adjacency_mat, only: yale_sparse

    implicit none 
    !private TODO
    
    integer(ip), protected :: verbose = 0_ip
    !! verbosity flag, allowed range 0 (no printing at all) -- 
    !! 3 (debug printing)
    
    integer(ip), protected :: ff_type
    !! Force field type selection flag (0 for AMBER, 1 for AMOEBA)
    
    integer(ip), protected :: ff_rules
    !! Force field exclusion rules (0 for Wang AL, 1 for Wang DL)

    integer(ip) :: solver !TODO remove
    !! Parameter that control how the polarization equations are solved.
    !! 1 = preconditioned conjugate gradient (default),
    !! 2 = jacobi iterations with DIIS extrapolation,
    !! 3 = matrix inversion
    
    integer(ip) :: matrix_vector !TODO remove
    !! Selection flag for the matrix-vectror product routine
    !! 1 = assemble the matrix using O(n^2) storage and use dgemv
    !! 2 = compute the matrix vector products in a direct fashion (default)
    !! 3 = use a fast multiplication technique (TODO)
  
    integer(ip) :: nmax !TODO remove
    !! maximum number of steps for iterative solvers
    
    real(rp) :: convergence !TODO remove
    !! convergence threshold (rms norm of the residual/increment) for 
    !! iterative solvers
  
    logical, protected :: amoeba
    
    integer(ip), protected :: mm_atoms !! number of MM atoms
    integer(ip), protected :: pol_atoms !! number of polarizable atoms
    integer(ip), protected :: ld_cart, ld_cder
!!     size of the cartesian multipolar distribution (i.e., (l+1)*(l+2)*(l+3)/6)
!!     this is 1 for AMBER (charges only), 10 for AMOEBA (up to quadrupoles). 
!!     this is also the size of the array that contains the electrostatic properties
!!     of the sources at the sources. ld_cder is the leading size of the derivative of
!!     such a distribution, which is 3 for AMBER and 19 for AMOEBA.
    integer(ip), protected :: n_ipd 
    !! number of induced point dipoles distributions 
    !! this is 1 for AMBER and 2 for AMOEBA
    
    ! arrays for the force field dependent exclusion factors. 
    
    real(rp), protected :: mscale(4)
    !! factors for charge-charge (or multipole-multipole) interactions

    real(rp), protected :: pscale(5)
    !! factors for chrage-ipd (or multipole-ipd) interactions.
    !! in AMOEBA, this is used to define the polarization field, i.e., the right-hand
    !! side to the polarization equations, and depends on the connectivity.
    
    real(rp), protected :: dscale(4)
    !! factors for multipoles-ipd interactions used to compute the direct field,
    !! which is used to define the polarization energy. these factors depend on 
    !! the polarization group "connectivity" (AMOEBA only)

    real(rp), protected :: uscale(4)
    !! factor for ipd-ipd interactions. these depend on the connectivity (AMBER)
    !! or on the polarization group " connectivity (AMOEBA)

    ! allocatable arrays which describe the polarizable system
    
    real(rp), allocatable, target :: cmm(:,:)
    !! Coordinates of MM atoms (3:mm_atoms)
    
    real(rp), allocatable, target :: cpol(:,:)
    !! Coordinates of polarizable atoms (3:pol_atoms)
    
    real(rp), allocatable, target :: q(:,:)
    !! Mutlipolar distribution (ld_cart:mm_atoms)
    !! For AMOEBA this is the rotated distribution.
    !! The order for the stored multipoles is
    !! q, px, py, pz, Qxx, Qxy, Qyy, Qxz, Qyx, Qzz.

    real(rp), allocatable, target :: q0(:,:)
    !! Unrotated utlipolar distribution (ld_cart:mm_atoms)
    !! (AMOEBA only)
    
    real(rp), allocatable, target :: ipd(:,:,:)
    !! induced point dipoles (3:pol_atoms:ipd) 
    
    real(rp), allocatable :: pol(:)
    !! Polarizabilities for each polarizable atom
    
    integer(ip), allocatable :: mm_polar(:)
    !! indices of the MM atoms that are polarizable

    integer(ip), allocatable :: polar_mm(:)
    !! positions of a polarizable atom in the mm atoms list
    
    type(yale_sparse), allocatable :: conn(:)
    !! connectivity matrices listing atoms separetad by 1, 2, 3 (and 4 -- only 
    !! for AMOEBA) bonds. 1st element is the adjacency matrix.

    integer(ip), allocatable :: mmat_polgrp(:)
    !! Polarizability group index for each MM site

    type(yale_sparse) :: polgrp_mmat
    !! For each polarization group index, list all the MM atoms included.
    !! It basically is a sparse boolean matrix of dimension 
    !! N_polgroups x N_mmatoms

    type(yale_sparse), allocatable :: pg_conn(:)
    !! Adjacency and connectivity matytrices between polarizability groups.
    !! Two groups are said to be adjacent if they are connected by a chemical 
    !! bond. The 1st element is the identity matrix for code simplicity.
    
    ! parameters for the definition of the rotation matrices for the multipoles:
    integer(ip), allocatable :: mol_frame(:)
    !! definition of the molecular frame
    !! convention: 0 ... do not rotate
    !!             1 ... z-then-x
    !!             2 ... bisector
    !!             3 ... z-only
    !!             4 ... z-bisector
    !!             5 ... 3-fold

    integer(ip), allocatable :: ix(:), iy(:), iz(:)
    !! neighboring atoms used to define the axes of the molecular frame
    ! TODO those quantities could probably be used only at need and
    ! then removed.

    ! scalars and arrays for various useful intermediates and results
    
    real(rp) :: e_ele, e_pol, e_qd, e_dd
    !! electrostatic and polarization energies, including 
    !! their breakdown into contributoins

    real(rp), allocatable :: v_qq(:,:)
    !! potential of MM permanent multipoles at MM sites; 
    !! shaped (ld_cart, mm_atoms).
    real(rp), allocatable :: dv_qq(:,:)
    !! derivative of v_qq TODO; shaped (ld_cder, mm_atoms)
  
    real(rp), allocatable :: ef_qd(:,:,:)
    !! electric field of MM permanent multipoles at POL sites; 
    !! shaped (3, pol_atoms, n_ipd)
    real(rp), allocatable :: def_qd(:,:,:)
    !! derivative of ef_qd TODO; shaped (3, pol_atoms, n_ipd)
  
    real(rp), allocatable :: v_dq(:,:), dv_dq(:,:)
    !! potential (and higher order terms) of the induced point 
    !! dipoles at the charges (multipoles) and its derivatives
    
    real(rp), allocatable :: ef_dd(:,:,:), def_dd(:,:,:)
    !! field of the ipd at the ipd and its derivatives
    
    real(rp),    allocatable :: thole(:)
    !! array to store the thole factors for computing damping functions
    
    contains

    subroutine set_verbosity(v)
        integer(ip), intent(in) :: v

        if( v < 0 ) then
            verbose = 0_ip
        else if( v > 3 ) then 
            verbose = 3_ip
        else
            verbose = v
        end if

    end subroutine set_verbosity

    subroutine mmpol_init(l_ff_type, l_ff_rules, l_mm_atoms, l_pol_atoms)
        !! Performs all the memory allocation and vector initialization
        !! needed to run the openMMPol library
        
        use mod_memory, only: ip, rp, mallocate

        implicit none

        integer(ip), intent(in) :: l_ff_type
        !! Force field type used in initialization
        
        integer(ip), intent(in) :: l_ff_rules
        !! Exclusion rules type used in initialization
        
        integer(ip), intent(in) :: l_mm_atoms
        !! Number of MM atoms used in initialization
        
        integer(ip), intent(in) :: l_pol_atoms
        !! Number of polarizable atoms used in initialization
        
        ! FF related settings
        ff_type = l_ff_type
        ff_rules = l_ff_rules
        mm_atoms = l_mm_atoms
        pol_atoms = l_pol_atoms

        if(ff_type == 1) then
            amoeba = .true.
            ld_cart = 10_ip
            ld_cder = 19_ip
            n_ipd = 2_ip
        else if(ff_type == 0) then
            amoeba = .false.
            ld_cart = 1_ip
            ld_cder = 3_ip
            n_ipd = 1_ip
        end if
  
        call set_screening_parameters()
        
        ! Memory allocation
        call mallocate('mmpol_init [cmm]', 3_ip, mm_atoms, cmm)
        call mallocate('mmpol_init [q]', ld_cart, mm_atoms, q)
        call mallocate('mmpol_init [pol]', pol_atoms, pol)
        call mallocate('mmpol_init [cpol]', 3_ip, pol_atoms, cpol)
        call mallocate('mmpol_init [polar_mm]', pol_atoms, polar_mm)
        call mallocate('mmpol_init [mm_polar]', mm_atoms, mm_polar)
        call mallocate('mmpol_init [thole]', mm_atoms, thole)
        call mallocate('mmpol_init [idp]', 3_ip, pol_atoms, n_ipd, ipd) 
        ipd = 0.0_rp
        allocate(conn(1)) 
        ! Temporary allocation, it should be allocated of the proper
        ! size when all the connectivity matricies are built, now
        ! it should only contain adjacency matrix.

        if (amoeba) then
            ! Extra quantities that should be allocated only
            ! for AMOEBA
            call mallocate('mmpol_init [q0]', ld_cart, mm_atoms, q0)
            
            call mallocate('mmpol_init [mmat_polgrp]', mm_atoms, mmat_polgrp)

            call mallocate('mmpol_init [mol_frame]', mm_atoms, mol_frame)
            call mallocate('mmpol_init [ix]', mm_atoms, ix)
            call mallocate('mmpol_init [iy]', mm_atoms, iy)
            call mallocate('mmpol_init [iz]', mm_atoms, iz)
        end if
  
        call mallocate('mmpol_init [v_qq]', ld_cart, mm_atoms, v_qq)
        v_qq = 0.0_rp
        call mallocate('mmpol_init [dv_qq]', ld_cder, mm_atoms, dv_qq)
        dv_qq = 0.0_rp
        
        call mallocate('mmpol_init [v_dq]', ld_cart, mm_atoms, v_dq)
        v_dq = 0.0_rp
        call mallocate('mmpol_init [dv_dq]', ld_cder, mm_atoms, dv_dq)
        dv_dq = 0.0_rp
        call mallocate('mmpol_init [ef_qd]', 3_ip, pol_atoms, n_ipd, ef_qd)
        ef_qd = 0.0_rp
        call mallocate('mmpol_init [def_qd]', 3_ip, pol_atoms, n_ipd, def_qd)
        def_qd = 0.0_rp
        
        call mallocate('mmpol_init [ef_dd]', 3_ip, pol_atoms, n_ipd, ef_dd)
        ef_dd = 0.0_rp
        call mallocate('mmpol_init [def_dd]', 6_ip, pol_atoms, n_ipd, def_dd)
        def_dd = 0.0_rp
      
    end subroutine mmpol_init

    subroutine mmpol_prepare()
        !! Compute some derived quantities from the input that 
        !! are used during the calculation. The upstream code have
        !! to provide cmm, q, pol, adjacency matrix and in
        !! the case of AMOEBA also multipoles rotation information, and 
        !! polarization group information.   
        !! This routine    
        !!   * compute connectivity lists from connected atoms    
        !!   * invert polar_mm list creating mm_polar   
        !!   * populate cpol list of coordinates   
        !!   * compute factors for thole damping    
        !!   * scales by 1/3 AMOEBA quadrupoles (?)    
        !!   * Build list for polarization groups, compute groups connectivity   
        !!   * performs multipoles rotation   

        use mod_adjacency_mat, only: build_conn_upto_n, matcpy

        implicit none

        integer(ip) :: i
        real(rp) :: xx(3) ! TODO remove this variable
        
        type(yale_sparse) :: adj, pg_adj

        ! compute connectivity lists from connected atoms
        call matcpy(conn(1), adj)
        deallocate(conn)

        if(amoeba) then 
            ! Amoeba needs connectivity matrices up to atoms separated  by 3 
            ! bonds
            call build_conn_upto_n(adj, 4, conn, .false.)
        else
            call build_conn_upto_n(adj, 3, conn, .false.)
        end if
        
        ! invert mm_polar list creating mm_polar
        mm_polar(:) = 0
        do i = 1, pol_atoms
            mm_polar(polar_mm(i)) = i
        end do

        ! populate cpol list of coordinates
        do i = 1, pol_atoms
            cpol(:,i) = cmm(:, polar_mm(i))
        end do

        ! compute factors for thole damping
        call thole_init()

        if(amoeba) then
            ! Copy multipoles from q to q0
            q0 = q

            ! scales by 1/3 AMOEBA quadrupoles (?)
            ! Mysterious division of multipoles by three
            ! FL told me that it was done like that in
            ! Tinker
            q0(5:10,:) = q0(5:10,:) / 3.0_rp

            ! polarization groups connectivity list
            call reverse_polgrp_tab(mmat_polgrp, polgrp_mmat)
            call build_pg_adjacency_matrix(pg_adj)
            call build_conn_upto_n(pg_adj, 3, pg_conn, .true.)

            ! performs multipoles rotation
            call rotate_multipoles(.false.,xx,xx)
        end if

    end subroutine mmpol_prepare

    subroutine mmpol_terminate()
        !! Performs all the deallocation needed at the end of the 
        !! calculation
        use mod_memory, only: mfree
        use mod_adjacency_mat, only: matfree

        implicit none 

        integer(ip) :: i

        call mfree('mmpol_terminate [cmm]', cmm)
        call mfree('mmpol_terminate [q]', q)
        call mfree('mmpol_terminate [pol]', pol)
        call mfree('mmpol_terminate [cpol]', cpol)
        call mfree('mmpol_terminate [polar_mm]', polar_mm)
        call mfree('mmpol_terminate [mm_polar]', mm_polar)
        call mfree('mmpol_terminate [thole]', thole)
        call mfree('mmpol_terminate [idp]', ipd) 
        call mfree('mmpol_terminate [v_qq]', v_qq)
        call mfree('mmpol_terminate [ef_qd]', ef_qd)
        call mfree('mmpol_terminate [dv_qq]',  dv_qq)
        call mfree('mmpol_terminate [def_qd]', def_qd)
        call mfree('mmpol_terminate [v_dq]', v_dq)
        call mfree('mmpol_terminate [ef_dd]', ef_dd)
        call mfree('mmpol_terminate [dv_dq]', dv_dq)
        call mfree('mmpol_terminate [def_dd]', def_dd)
        
        do i=1, size(conn)
            call matfree(conn(i))
        end do
        deallocate(conn)

        if (amoeba) then
            ! Extra quantities that should be deallocated only
            ! for AMOEBA
            
            ! Second set of multipoles (q0 = unrotated, q=rotated)
            call mfree('mmpol_terminate [q0]', q0)
            
            ! Polarization groups
            call mfree('mmpol_terminate [mmat_polgrp]', mmat_polgrp)
            do i=1, size(pg_conn)
                call matfree(pg_conn(i))
            end do
            deallocate(pg_conn)
            call matfree(polgrp_mmat)

            ! Information for multipoles rotation
            call mfree('mmpol_terminate [mol_frame]', mol_frame)
            call mfree('mmpol_terminate [ix]', ix)
            call mfree('mmpol_terminate [iy]', iy)
            call mfree('mmpol_terminate [iz]', iz)
        end if

    end subroutine mmpol_terminate
    
    subroutine fatal_error(message)
        !! Prints a message and exit from the program. This
        !! function should be used in all the conditions 
        !! where the program cannot proceed.

        implicit none
      
        character (len=*) message
        !! Message to print before the program termination

        write(6, '(t3,a)') message
        stop '   error termination for open_mmpol.'
    end subroutine fatal_error

    subroutine thole_init()
        ! This routine compute the thole factors and stores
        ! them in a vector. TODO add reference
        use mod_constants, only: a_wal, a_wdl
        
        implicit none
        
        integer(ip) :: i, j
        
        thole = 0.0_rp
        
        do i = 1, pol_atoms
            j = polar_mm(i)
            thole(j) = pol(i) ** (1.0_rp/6.0_rp)
        end do
        
        if(.not. amoeba) then
            if(ff_rules == 0) &
                thole = thole * sqrt(a_wal)
            if(ff_rules == 1) &
                thole = thole * sqrt(a_wdl)
        end if
    end subroutine thole_init

    subroutine reverse_polgrp_tab(mm2pg, pg2mm)
        !! Takes as argument an array of polarization group index for each
        !! atom, and create a list of atms in each group using the boolean
        !! sparse matrix format (saved as Yale format).
        
        implicit none

        integer(ip), intent(in) :: mm2pg(mm_atoms)
        !! Index of polarization group for each MM atom
        type(yale_sparse), intent(out) :: pg2mm
        !! Indices of atoms included in each polarization group;
        !! Atom indeces for the n-th group are found at 
        !! pg2mm%ci(pg2mm%ri(n):pg2mm%ri(n+1)-1)

        integer(ip) :: i, j

        ! Allocation of Yale fmt sparse matrix
        pg2mm%n = maxval(mm2pg)
        allocate(pg2mm%ri(pg2mm%n+1))
        allocate(pg2mm%ci(mm_atoms))
        pg2mm%ri(1) = 1

        do i=1, pg2mm%n
            pg2mm%ri(i+1) = pg2mm%ri(i)
            
            do j=1, mm_atoms
                if(mm2pg(j) /= i) cycle
                
                pg2mm%ci(pg2mm%ri(i+1)) = j
                pg2mm%ri(i+1) = pg2mm%ri(i+1) + 1
            end do
        end do
        
        if(verbose == 3_ip) then
            do i=1, pg2mm%n
                write(*, '("Atoms in polarization group ", I5, ":", *(I5))') &
                      i, pg2mm%ci(pg2mm%ri(i):pg2mm%ri(i+1)-1)
            end do
        end if
    end subroutine reverse_polgrp_tab

    subroutine build_pg_adjacency_matrix(adj)
        !! Builds the adjacency matrix of polarization groups starting from
        !! atomic adjacency matrix and list of polarization groups indices.

        use mod_adjacency_mat, only: reallocate_mat 

        implicit none

        type(yale_sparse), intent(out) :: adj
        !! The group adjacency matrix to be saved.

        integer(ip) :: npg, pg1, pg2, atm1, atm2, i, j

        npg = polgrp_mmat%n

        adj%n = npg
        allocate(adj%ri(adj%n+1))
        allocate(adj%ci(adj%n*2))
        adj%ri(1) = 1

        do pg1=1, npg
            ! For each polarization group
            adj%ri(pg1+1) = adj%ri(pg1)

            do i=polgrp_mmat%ri(pg1), polgrp_mmat%ri(pg1+1)-1
                ! Loop on every atom of the group
                atm1 = polgrp_mmat%ci(i)
                do j=conn(1)%ri(atm1), conn(1)%ri(atm1+1)-1
                    ! Loop on each connected atom...
                    atm2 = conn(1)%ci(j)

                    ! If the two atoms are in different PG, then the two
                    ! polarization groups are connected. 
                    if(mmat_polgrp(atm1) /= mmat_polgrp(atm2) .and. &
                       ! if the group is not already present in the matrix
                       all(adj%ci(adj%ri(pg1):adj%ri(pg1+1)-1) /= mmat_polgrp(atm2))) then
                        adj%ci(adj%ri(pg1+1)) = mmat_polgrp(atm2)
                        adj%ri(pg1+1) = adj%ri(pg1+1) + 1
                        if(adj%ri(pg1+1) > size(adj%ci)) then
                            ! If matrix is too small, it could be enlarged...
                            call reallocate_mat(adj, size(adj%ci)+adj%n)
                        end if
                    end if
                end do
            end do
        end do
        
        ! Finally trim the output matrix
        call reallocate_mat(adj, adj%ri(adj%n+1)-1)

    end subroutine build_pg_adjacency_matrix
    
    subroutine set_screening_parameters()
        !! Subroutine to initialize the screening parameters
        use mod_constants, only: one, zero, pt5
        
        implicit none
        real(rp), parameter :: pt4 = 0.40_rp, pt8 = 0.80_rp
        if (ff_type.eq.0 .and. ff_rules.eq.0) then
            ! WangAL
            mscale(1) = zero
            mscale(2) = zero
            mscale(3) = one
            mscale(4) = one

            pscale(1) = zero
            pscale(2) = zero
            pscale(3) = one
            pscale(4) = one
            pscale(5) = one
            
            dscale(1) = zero
            dscale(2) = zero
            dscale(3) = one
            dscale(4) = one
            
            uscale(1) = zero
            uscale(2) = zero
            uscale(3) = one
            uscale(4) = one
        else if (ff_type.eq.0 .and. ff_rules.eq.1) then
            ! WangDL
            mscale(1) = one
            mscale(2) = one
            mscale(3) = one
            mscale(4) = one
            
            pscale(1) = one
            pscale(2) = one
            pscale(3) = one
            pscale(4) = one
            pscale(5) = one
            
            dscale(1) = one
            dscale(2) = one
            dscale(3) = one
            dscale(4) = one
            
            uscale(1) = one
            uscale(2) = one
            uscale(3) = one
            uscale(4) = one
        else if (ff_type.eq.1) then
            ! AMOEBA
            mscale(1) = zero
            mscale(2) = zero
            mscale(3) = pt4
            mscale(4) = pt8
            
            pscale(1) = zero
            pscale(2) = zero
            pscale(3) = one
            pscale(4) = one
            pscale(5) = pt5
            
            dscale(1) = zero
            dscale(2) = one
            dscale(3) = one
            dscale(4) = one
            
            uscale(1) = one
            uscale(2) = one
            uscale(3) = one
            uscale(4) = one
        else
            call fatal_error('the required force field is not implemented.')
        end if
    end subroutine set_screening_parameters

end module mod_mmpol