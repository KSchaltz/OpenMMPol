! Wrapper function for open-mmpol library
module mod_ommp_interface
    use iso_c_binding
    use mod_memory, only: ommp_integer => ip, &
                          ommp_real => rp

    use mod_mmpol, only: ommp_cmm => cmm, &
                         ommp_cpol => cpol, &
                         ommp_q => q, &
                         ommp_ipd => ipd, &
                         ommp_polar_mm => polar_mm, &
                         ommp_mm_atoms => mm_atoms, &
                         ommp_n_ipd => n_ipd, &
                         ommp_pol_atoms => pol_atoms, &
                         ommp_ld_cart => ld_cart, &
                         ommp_is_amoeba => amoeba

    use mod_constants, only: OMMP_FF_AMOEBA, OMMP_FF_WANG_AL, OMMP_FF_WANG_DL, &
                             OMMP_SOLVER_CG, OMMP_SOLVER_DIIS, &
                             OMMP_SOLVER_INVERSION, OMMP_SOLVER_DEFAULT, &
                             OMMP_MATV_INCORE, OMMP_MATV_DIRECT, &
                             OMMP_MATV_DEFAULT, &
                             OMMP_AMOEBA_D, OMMP_AMOEBA_P, &
                             OMMP_VERBOSE_DEBUG, OMMP_VERBOSE_HIGH, &
                             OMMP_VERBOSE_LOW, OMMP_VERBOSE_NONE
    use mod_constants, only: OMMP_STR_CHAR_MAX

    implicit none
    private :: c2f_string, OMMP_STR_CHAR_MAX

    contains
        
        function ommp_get_cmm() bind(c, name='ommp_get_cmm')
            use mod_mmpol, only: cmm
            type(c_ptr) :: ommp_get_cmm

            ommp_get_cmm = c_loc(cmm)
        end function ommp_get_cmm

        function ommp_get_cpol() bind(c, name='ommp_get_cpol')
            use mod_mmpol, only: cpol
            type(c_ptr) :: ommp_get_cpol

            ommp_get_cpol = c_loc(cpol)
        end function ommp_get_cpol

        function ommp_get_q() bind(c, name='ommp_get_q')
            use mod_mmpol, only: q
            type(c_ptr) :: ommp_get_q

            ommp_get_q = c_loc(q)
        end function ommp_get_q

        function ommp_get_ipd() bind(c, name='ommp_get_ipd')
            use mod_mmpol, only: ipd
            type(c_ptr) :: ommp_get_ipd

            ommp_get_ipd = c_loc(ipd)
        end function ommp_get_ipd
        
        function ommp_get_polar_mm() bind(c, name='ommp_get_polar_mm')
            use mod_mmpol, only: polar_mm
            type(c_ptr) :: ommp_get_polar_mm

            ommp_get_polar_mm = c_loc(polar_mm)
        end function ommp_get_polar_mm

        function ommp_get_mm_atoms() bind(c, name='ommp_get_mm_atoms')
            use mod_mmpol, only: mm_atoms
            implicit none

            integer(ommp_integer) :: ommp_get_mm_atoms

            ommp_get_mm_atoms = mm_atoms
        end function ommp_get_mm_atoms
        
        function ommp_get_pol_atoms() bind(c, name='ommp_get_pol_atoms')
            use mod_mmpol, only: pol_atoms
            implicit none

            integer(ommp_integer) :: ommp_get_pol_atoms

            ommp_get_pol_atoms = pol_atoms
        end function ommp_get_pol_atoms

        function get_n_ipd() bind(c, name='get_n_ipd')
            use mod_mmpol, only: n_ipd
            implicit none

            integer(ommp_integer) :: get_n_ipd

            get_n_ipd = n_ipd
        end function get_n_ipd

        function ommp_get_ld_cart() bind(c, name='ommp_get_ld_cart')
            use mod_mmpol, only: ld_cart
            implicit none

            integer(ommp_integer) :: ommp_get_ld_cart

            ommp_get_ld_cart = ld_cart
        end function ommp_get_ld_cart

        function ommp_ff_is_amoeba() bind(c, name='ommp_ff_is_amoeba')
            use mod_mmpol, only: amoeba
            implicit none

            logical(c_bool) :: ommp_ff_is_amoeba

            ommp_ff_is_amoeba = amoeba
        end function ommp_ff_is_amoeba
        
        subroutine ommp_set_verbose(verb) bind(c, name='ommp_set_verbose')
            use mod_io, only: set_verbosity
            implicit none 

            integer(ommp_integer), intent(in), value :: verb

            call set_verbosity(verb)
        end subroutine ommp_set_verbose

        subroutine ommp_print_summary() bind(c, name='ommp_print_summary')
            use mod_mmpol, only: mmpol_ommp_print_summary

            implicit none
            
            call mmpol_ommp_print_summary()

        end subroutine ommp_print_summary
        
        subroutine ommp_print_summary_to_file(filename) &
                bind(c, name='ommp_print_summary_to_file')
            use mod_mmpol, only: mmpol_ommp_print_summary

            implicit none
            
            character(kind=c_char), intent(in) :: filename(OMMP_STR_CHAR_MAX)
            character(len=OMMP_STR_CHAR_MAX) :: output_file
            
            call c2f_string(filename, output_file)
            call mmpol_ommp_print_summary(output_file)

        end subroutine ommp_print_summary_to_file

        subroutine c2f_string(c_str, f_str)
            implicit none
            
            character(kind=c_char), intent(in) :: c_str(:)
            character(len=*), intent(out) :: f_str

            integer :: i 

            i = 1
            do while(c_str(i) /= c_null_char)
                f_str(i:i) = c_str(i)
                i = i + 1
            end do

            do i = i, len(f_str)
                f_str(i:i) = ' '
            end do

            f_str = trim(f_str)
        end subroutine c2f_string
        
        subroutine ommp_init_xyz(xyzfile, prmfile) &
                bind(c, name='ommp_init_xyz')
            use mod_inputloader, only : mmpol_init_from_xyz
            
            implicit none
            
            character(kind=c_char), intent(in) :: xyzfile(OMMP_STR_CHAR_MAX), & 
                                                  prmfile(OMMP_STR_CHAR_MAX)
            character(len=OMMP_STR_CHAR_MAX) :: xyz_file, prm_file

            call c2f_string(prmfile, prm_file)
            call c2f_string(xyzfile, xyz_file)
            call mmpol_init_from_xyz(xyz_file, prm_file)
        end subroutine 
        
        subroutine C_ommp_init_mmp(filename) bind(c, name='ommp_init_mmp')
            use mod_inputloader, only : mmpol_init_from_mmp
            
            implicit none
            
            character(kind=c_char), intent(in) :: filename(OMMP_STR_CHAR_MAX)
            character(len=OMMP_STR_CHAR_MAX) :: input_file

            call c2f_string(filename, input_file)
            call mmpol_init_from_mmp(input_file)
        end subroutine 
        
        subroutine ommp_init_mmp(filename)
            use mod_inputloader, only : mmpol_init_from_mmp
            
            implicit none
            
            character(len=*) :: filename

            call mmpol_init_from_mmp(trim(filename))
        end subroutine 

        subroutine ommp_set_external_field(ext_field, solver) &
                bind(c, name='ommp_set_external_field')
            !! This function get an external field and solve the polarization
            !! system in the presence of the provided external field.
            use mod_polarization, only: polarization, ipd_done
            use mod_mmpol, only: pol_atoms, n_ipd, ipd
            use mod_electrostatics, only: e_m2d, prepare_M2D
            use mod_memory, only: mallocate, mfree

            implicit none
            
            real(ommp_real), intent(in) :: ext_field(3, pol_atoms)
            integer(ommp_integer), intent(in), value :: solver

            real(ommp_real), allocatable :: ef(:,:,:)
            integer :: i

            ipd_done = .false.
            
            call mallocate('ommp_get_polelec_energy [ef]', 3, pol_atoms, n_ipd, ef)
            call prepare_M2D()
            do i=1, n_ipd
                ef(:,:,i) = e_m2d(:,:,i) + ext_field
            end do
            call polarization(ef, ipd, solver)
            call mfree('ommp_get_polelec_energy [ef]', ef)

        end subroutine ommp_set_external_field

        subroutine ommp_get_polelec_energy(epol) &
                bind(c, name='ommp_get_polelec_energy')
            !! Solve the polarization equation for a certain external field
            !! and compute the interaction energy of the induced dipoles with
            !! themselves and fixed multipoles.

            use mod_polarization, only: polarization, ipd_done
            use mod_mmpol, only: ipd
            use mod_electrostatics, only: e_m2d, prepare_M2D, energy_MM_pol
            use mod_constants, only: OMMP_SOLVER_DEFAULT

            implicit none
            
            real(ommp_real), intent(out) :: epol

            if(.not. ipd_done) then
                !! Solve the polarization system without external field
                call prepare_M2D()
                call polarization(e_m2d, ipd, OMMP_SOLVER_DEFAULT)
            end if
            call energy_MM_pol(epol) 
        end subroutine

        subroutine ommp_get_fixedelec_energy(emm) &
                bind(c, name='ommp_get_fixedelec_energy')
            ! Get the interaction energy of fixed multipoles
            use mod_electrostatics, only: energy_MM_MM, energy_MM_pol

            implicit none
            real(ommp_real), intent(out) :: emm

            emm = 0.0
            
            call energy_MM_MM(emm)
        end subroutine

        subroutine ommp_get_urey_energy(eub) bind(c, name='ommp_get_urey_energy')
            
            use mod_bonded, only: urey_potential

            implicit none
            real(ommp_real), intent(inout) :: eub

            eub = 0.0
            call urey_potential(eub)
        end subroutine
        
        subroutine ommp_get_strbnd_energy(eba) bind(c, name='ommp_get_strbnd_energy')
            
            use mod_bonded, only: strbnd_potential

            implicit none
            real(ommp_real), intent(inout) :: eba

            eba = 0.0
            call strbnd_potential(eba)
        end subroutine
        
        subroutine ommp_get_angle_energy(eang) bind(c, name='ommp_get_angle_energy')
            
            use mod_bonded, only: angle_potential

            implicit none
            real(ommp_real), intent(inout) :: eang

            eang = 0.0
            call angle_potential(eang)
        end subroutine
        
        subroutine ommp_get_angtor_energy(eat) bind(c, name='ommp_get_angtor_energy')
            
            use mod_bonded, only: angtor_potential

            implicit none
            real(ommp_real), intent(inout) :: eat

            eat = 0.0
            call angtor_potential(eat)
        end subroutine
        
        subroutine ommp_get_strtor_energy(ebt) bind(c, name='ommp_get_strtor_energy')
            
            use mod_bonded, only: strtor_potential

            implicit none
            real(ommp_real), intent(inout) :: ebt

            ebt = 0.0
            call strtor_potential(ebt)
        end subroutine
        
        subroutine ommp_get_bond_energy(ebnd) bind(c, name='ommp_get_bond_energy')
            
            use mod_bonded, only: bond_potential

            implicit none
            real(ommp_real), intent(inout) :: ebnd

            ebnd = 0.0
            call bond_potential(ebnd)
        end subroutine
        
        subroutine ommp_get_opb_energy(eopb) bind(c, name='ommp_get_opb_energy')
            
            use mod_bonded, only: opb_potential

            implicit none
            real(ommp_real), intent(inout) :: eopb

            eopb = 0.0
            call opb_potential(eopb)
        end subroutine
        
        subroutine ommp_get_pitors_energy(epitors) bind(c, name='ommp_get_pitors_energy')
            
            use mod_bonded, only: pitors_potential

            implicit none
            real(ommp_real), intent(inout) :: epitors

            epitors = 0.0
            call pitors_potential(epitors)
        end subroutine
        
        subroutine ommp_get_torsion_energy(et) bind(c, name='ommp_get_torsion_energy')
            
            use mod_bonded, only: torsion_potential

            implicit none
            real(ommp_real), intent(inout) :: et

            et = 0.0
            call torsion_potential(et)
        end subroutine
        
        subroutine ommp_get_tortor_energy(ett) bind(c, name='ommp_get_tortor_energy')
            
            use mod_bonded, only: tortor_potential

            implicit none
            real(ommp_real), intent(inout) :: ett

            ett = 0.0
            call tortor_potential(ett)
        end subroutine
        
        subroutine ommp_get_vdw_energy(evdw) bind(c, name='ommp_get_vdw_energy')
            
            use mod_nonbonded, only: vdw_potential

            implicit none
            real(ommp_real), intent(inout) :: evdw

            evdw = 0.0
            call vdw_potential(evdw)
        end subroutine

        subroutine ommp_terminate() bind(c, name='ommp_terminate')
            use mod_mmpol, only: mmpol_terminate
            use mod_bonded, only: terminate_bonded
            use mod_nonbonded, only: vdw_terminate
            use mod_electrostatics, only: electrostatics_terminate

            implicit none

            call mmpol_terminate()
            call terminate_bonded()
            call vdw_terminate()
            call electrostatics_terminate()

        end subroutine

#ifdef USE_HDF5
        subroutine ommp_init_hdf5(filename) bind(c, name='ommp_init_hdf5')
            !! This function is an interface for saving an HDF5 file 
            !! with all the data contained in mmpol module using
            !! [[mod_io:mmpol_save_as_hdf5]]
            use mod_iohdf5, only: mmpol_init_from_hdf5

            implicit none
            
            character(kind=c_char), intent(in) :: filename(OMMP_STR_CHAR_MAX)
            character(len=OMMP_STR_CHAR_MAX) :: hdf5in
            integer(ommp_integer) :: ok

            call c2f_string(filename, hdf5in)
            call mmpol_init_from_hdf5(hdf5in, ok)
            
        end subroutine ommp_init_hdf5
        
        function ommp_write_hdf5(filename) bind(c, name='ommp_write_hdf5')
            !! This function is an interface for saving an HDF5 file 
            !! with all the data contained in mmpol module using
            !! [[mod_io:mmpol_save_as_hdf5]]
            use mod_iohdf5, only: mmpol_save_as_hdf5

            implicit none
            
            character(kind=c_char), intent(in) :: filename(OMMP_STR_CHAR_MAX)
            character(len=OMMP_STR_CHAR_MAX) :: hdf5out
            integer(ommp_integer) :: ommp_write_hdf5

            call c2f_string(filename, hdf5out)
            call mmpol_save_as_hdf5(hdf5out, ommp_write_hdf5)
            
        end function ommp_write_hdf5
#endif

end module mod_ommp_interface

