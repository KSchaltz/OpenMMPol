program main
  use mmpol
  use elstat
  use polar
  implicit none
  character (len=120), dimension(2) :: args

!
! the name of the mmpol input file and, optionally, the name of the
! mmpol binary file are provided in input as arguments to the program:
!
  if (iargc() .eq. 0) then
!
!   no argument provided
!
  else if (iargc() .eq. 1) then
    call getarg(1, args(1))
    input_file = trim(args(1))
    scratch_file = input_file(1:len_inname-4)//'.rwf' 
  else if (iargc() .eq. 2) then
    call getarg(1, args(1))
    call getarg(2, args(2))
    input_file = trim(args(1))
    scratch_file = trim(args(2))
  end if
!
  call mmpol_init
  
  !
  ! Testing AMOEBA FF
  !
! call print_matrix(.true.,'multipoles :',ld_cart,mm_atoms,ld_cart,mm_atoms,q)
! call electrostatics(0,0,0,v_qq,ef_qd,dv_qq,def_qd) 
! call electrostatics(0,1,0,v_qq,ef_qd,dv_qq,def_qd)
! call electrostatics(0,0,1,v_qq,ef_qd,dv_qq,def_qd) 
  call electrostatics(0,1,1,v_qq,ef_qd,dv_qq,def_qd)
  
! call print_matrix(.true.,'VMM:',mm_atoms,ld_cart,mm_atoms,ld_cart,transpose(v_qq))               ! OK
! call print_matrix(.true.,'EMM 1:',pol_atoms,3,pol_atoms,3,transpose(ef_qd(:,:,1)))               ! OK
! call print_matrix(.true.,'EMM 2:',pol_atoms,3,pol_atoms,3,transpose(ef_qd(:,:,2)))               ! OK
! call print_matrix(.true.,'dVMM@MM:',mm_atoms,ld_cder,mm_atoms,ld_cder,transpose(dv_qq))          ! OK 
  call print_matrix(.true.,'GMM@MM 1:',pol_atoms,6,pol_atoms,6,transpose(def_qd(:,:,1)))           ! 
  call print_matrix(.true.,'GMM@MM 2:',pol_atoms,6,pol_atoms,6,transpose(def_qd(:,:,2)))
end program main
