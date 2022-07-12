module mod_bonded
    !! Module to handle the bonded part of the FF, it closely follows the 
    !! AMOEBA functional form.
    
    use mod_memory, only: ip, rp
    
    implicit none
    private

    ! Bond
    integer(ip) :: nbond
    integer(ip), allocatable :: bondat(:,:)
    real(rp) :: bond_cubic, bond_quartic
    real(rp), allocatable :: kbond(:), l0bond(:)
    public :: bond_init, bond_potential, bondat, kbond, &
              l0bond, bond_cubic, bond_quartic

    ! Angle
    integer(ip) :: nangle
    integer(ip), allocatable :: angleat(:,:), anglety(:), angauxat(:)
    integer(ip), parameter, public :: OMMP_ANG_SIMPLE = 0, &
                                      OMMP_ANG_H0 = 1, &
                                      OMMP_ANG_H1 = 2, &
                                      OMMP_ANG_H2 = 3, &
                                      OMMP_ANG_INPLANE = 4, &
                                      OMMP_ANG_INPLANE_H0 = 5, &
                                      OMMP_ANG_INPLANE_H1 = 6
    real(rp) :: angle_cubic, angle_quartic, angle_pentic, angle_sextic
    real(rp), allocatable :: kangle(:), eqangle(:)
    public :: angle_init, angle_potential, angleat, anglety, kangle, eqangle, &
              angle_cubic, angle_quartic, angle_pentic, angle_sextic

    ! Stretch-Bend
    integer(ip) :: nstrbnd
    integer(ip), allocatable :: strbndat(:,:)
    real(rp), allocatable :: strbndk1(:), strbndk2(:), strbndthet0(:), &
                             strbndl10(:), strbndl20(:)
    public :: strbnd_init, strbnd_potential, strbndat, strbndk1, &
              strbndk2, strbndl10, strbndl20, strbndthet0

    ! Urey-Bradley
    integer(ip) :: nurey
    integer(ip), allocatable :: ureyat(:,:)
    real(rp) :: urey_cubic, urey_quartic
    real(rp), allocatable :: kurey(:), l0urey(:)
    public :: urey_init, urey_potential, ureyat, kurey, &
              l0urey, urey_cubic, urey_quartic

    contains

    subroutine bond_init(n) 
        !! Initialize bond stretching arrays

        use mod_memory, only: mallocate

        implicit none

        integer(ip) :: n
        !! Number of bond stretching functions in the potential
        !! energy of the system

        call mallocate('bond_init [bondat]', 2, n, bondat)
        call mallocate('bond_init [kbond]', n, kbond)
        call mallocate('bond_init [l0bond]', n, l0bond)

        nbond = n
        bond_cubic = 0.0_rp
        bond_quartic = 0.0_rp

    end subroutine bond_init

    subroutine bond_potential(V)
        !! Compute the bond-stretching potential

        use mod_constants, only : eps_rp
        use mod_mmpol, only: cmm

        implicit none

        real(rp), intent(inout) :: V
        !! Bond potential, result will be added to V

        integer :: i
        logical :: use_cubic, use_quartic
        real(rp) :: dr(3), l, dl, dl2

        use_cubic = (abs(bond_cubic) > eps_rp)
        use_quartic = (abs(bond_quartic) > eps_rp)

        if(.not. use_cubic .and. .not. use_quartic) then
            ! This is just a regular harmonic potential
            do i=1, nbond
                dr = cmm(:,bondat(1,i)) - cmm(:,bondat(2,i))
                l = sqrt(dot_product(dr, dr))
                dl = l - l0bond(i)
                
                V = V + kbond(i) * dl * dl
            end do
        else
            do i=1, nbond
                dr = cmm(:,bondat(1,i)) - cmm(:,bondat(2,i))
                l = sqrt(dot_product(dr, dr))
                dl = l - l0bond(i)
                dl2 = dl * dl

                V = V + kbond(i)*dl2 * (1.0_rp + bond_cubic*dl + bond_quartic*dl2)
            end do
        end if
        
    end subroutine bond_potential

    subroutine angle_init(n)
        use mod_memory, only: mallocate

        implicit none

        integer(ip) :: n
        !! Number of angle bending functions in the potential
        !! energy of the system

        call mallocate('angle_init [angleat]', 3, n, angleat)
        call mallocate('angle_init [anglety]', n, anglety)
        call mallocate('angle_init [angauxat]', n, angauxat)
        call mallocate('angle_init [kangle]', n, kangle)
        call mallocate('angle_init [eqangle]', n, eqangle)
        
        nangle = n
        angauxat = 0
        angle_cubic = 0.0_rp
        angle_quartic = 0.0_rp
        angle_pentic = 0.0_rp
        angle_sextic = 0.0_rp

    end subroutine angle_init

    subroutine angle_potential(V)
        use mod_mmpol, only: cmm, conn, fatal_error

        implicit none

        real(rp), intent(inout) :: V
        
        integer(ip) :: i, j
        real(rp) :: l1, l2, dr1(3), dr2(3), thet, d_theta
        real(rp), dimension(3) :: v_dist, plv1, plv2, pln, a, b, c, prj_b, aux

        do i=1, nangle
            if(anglety(i) == OMMP_ANG_SIMPLE .or. &
               anglety(i) == OMMP_ANG_H0 .or. &
               anglety(i) == OMMP_ANG_H1 .or. &
               anglety(i) == OMMP_ANG_H2) then
                dr1 = cmm(:, angleat(1,i)) - cmm(:, angleat(2,i))
                dr2 = cmm(:, angleat(3,i)) - cmm(:, angleat(2,i))
                l1 = sqrt(dot_product(dr1, dr1))
                l2 = sqrt(dot_product(dr2, dr2))

                thet = acos(dot_product(dr1, dr2)/(l1*l2))
                
                d_theta = thet-eqangle(i) 
                
                V = V + kangle(i) * d_theta**2 * (1.0 + angle_cubic*d_theta &
                    + angle_quartic*d_theta**2 + angle_pentic*d_theta**3 &
                    + angle_sextic*d_theta**4)

            else if(anglety(i) == OMMP_ANG_INPLANE .or. &
                    anglety(i) == OMMP_ANG_INPLANE_H0 .or. &
                    anglety(i) == OMMP_ANG_INPLANE_H1) then
                if(angauxat(i) < 1) then
                    ! Find the auxiliary atom used to define the projection
                    ! plane
                    if(conn(1)%ri(angleat(2,i)+1) - conn(1)%ri(angleat(2,i)) /= 3) then
                        call fatal_error("Angle IN-PLANE defined for a non-&
                                         &trigonal center")
                    end if 
                    do j=conn(1)%ri(angleat(2,i)), conn(1)%ri(angleat(2,i)+1)-1
                        if(conn(1)%ci(j) /= angleat(1,i) .and. &
                           conn(1)%ci(j) /= angleat(3,i)) then
                            angauxat(i) = conn(1)%ci(j)
                        endif
                    end do
                end if
                a = cmm(:, angleat(1,i))
                b = cmm(:, angleat(2,i))
                c = cmm(:, angleat(3,i))

                aux = cmm(:, angauxat(i))
                plv1 = a - aux
                plv2 = c - aux
                pln(1) = plv1(2)*plv2(3) - plv1(3)*plv2(2)
                pln(2) = plv1(3)*plv2(1) - plv1(1)*plv2(3)
                pln(3) = plv1(1)*plv2(2) - plv1(2)*plv2(1)
                pln = pln / sqrt(dot_product(pln, pln))

                v_dist = b - aux
                prj_b = b - dot_product(v_dist, pln) * pln 

                dr1 = cmm(:, angleat(1,i)) - prj_b
                dr2 = cmm(:, angleat(3,i)) - prj_b
                l1 = sqrt(dot_product(dr1, dr1))
                l2 = sqrt(dot_product(dr2, dr2))

                thet = acos(dot_product(dr1, dr2)/(l1*l2))
                
                d_theta = thet-eqangle(i) 
                
                V = V + kangle(i) * d_theta**2 * (1.0 + angle_cubic*d_theta &
                    + angle_quartic*d_theta**2 + angle_pentic*d_theta**3 &
                    + angle_sextic*d_theta**4)
            end if
        end do
    end subroutine angle_potential
    
    subroutine strbnd_init(n)
        !! Initialize Stretch-bend cross term potential

        use mod_memory, only: mallocate

        implicit none

        integer(ip) :: n
        !! Number of stretch-bend functions in the potential
        !! energy of the system

        call mallocate('strbnd_init [strbndat]', 3, n, strbndat)
        call mallocate('strbnd_init [strbndl10]', n, strbndl10)
        call mallocate('strbnd_init [strbndl20]', n, strbndl20)
        call mallocate('strbnd_init [strbndthet0]', n, strbndthet0)
        call mallocate('strbnd_init [strbndk1]', n, strbndk1)
        call mallocate('strbnd_init [strbndk2]', n, strbndk2)
        nstrbnd = n

    end subroutine strbnd_init

    subroutine strbnd_potential(V)
        !! Compute the stretch-bend cross term potential

        use mod_constants!, only : eps_rp
        use mod_mmpol, only: cmm, fatal_error

        implicit none

        real(rp), intent(inout) :: V
        !! Stretch-bend cross term potential, result will be added to V

        integer(ip) :: i, j, l1a, l1b, l2a, l2b
        real(rp) :: d_l1, d_l2, d_thet, dr1(3), dr2(3), l1, l2, thet
        logical :: l1_done, l2_done, thet_done

        do i=1, nstrbnd
            dr1 = cmm(:, strbndat(2,i)) - cmm(:, strbndat(1,i))
            l1 = norm2(dr1)
            d_l1 = l1 - strbndl10(i)
            
            dr2 = cmm(:,strbndat(2,i)) - cmm(:, strbndat(3,i))
            l2 = norm2(dr2)
            d_l2 = l2 - strbndl20(i)

            thet = acos(dot_product(dr1, dr2)/(l1*l2))
            d_thet = thet - strbndthet0(i) 
            
            V = V + (d_l1*strbndk1(i) + d_l2*strbndk2(i)) * d_thet
        end do
    end subroutine strbnd_potential
    
    subroutine urey_init(n) 
        !! Initialize Urey-Bradley potential arrays

        use mod_memory, only: mallocate

        implicit none

        integer(ip) :: n
        !! Number of Urey-Bradley functions in the potential
        !! energy of the system

        call mallocate('urey_init [ureya]', 2, n, ureyat)
        call mallocate('urey_init [kurey]', n, kurey)
        call mallocate('urey_init [l0urey]', n, l0urey)
        nurey = n
        urey_cubic = 0.0_rp
        urey_quartic = 0.0_rp

    end subroutine urey_init

    subroutine urey_potential(V)
        !! Compute the Urey-Bradley potential

        use mod_constants, only : eps_rp
        use mod_mmpol, only: cmm

        implicit none

        real(rp), intent(inout) :: V
        !! Urey-Bradley potential, result will be added to V

        integer :: i
        logical :: use_cubic, use_quartic
        real(rp) :: dr(3), l, dl, dl2

        use_cubic = (abs(urey_cubic) > eps_rp)
        use_quartic = (abs(urey_quartic) > eps_rp)

        if(.not. use_cubic .and. .not. use_quartic) then
            ! This is just a regular harmonic potential
            do i=1, nurey
                dr = cmm(:,ureyat(1,i)) - cmm(:,ureyat(2,i))
                l = sqrt(dot_product(dr, dr))
                dl = l - l0urey(i)
                V = V + kurey(i) * dl * dl
            end do
        else
            do i=1, nurey
                dr = cmm(:,ureyat(1,i)) - cmm(:,ureyat(2,i))
                l = sqrt(dot_product(dr, dr))
                dl = l - l0urey(i)
                dl2 = dl * dl

                V = V + kurey(i)*dl2 * (1.0_rp + urey_cubic*dl + urey_quartic*dl2)
            end do
        end if
        
    end subroutine urey_potential

end module mod_bonded
