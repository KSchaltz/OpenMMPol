! Wrapper function for open-mmpol library
subroutine w_mmpol_init(filename)
  use mmpol
  ! 
  implicit none
  character(len=120), intent(in) :: filename
  character(len=120) :: BsName

  input_file = filename
  BsName = filename(1:Scan(filename,'.',BACK=.true.))
  scratch_file = Trim(BsName)//'rwf'

  call mmpol_init
  
end subroutine 

subroutine do_mm 
  use precision
  use mmpol
  ! Perform the MM-only calculations of pot and field
  ! and return EMM

  implicit none
  
  ! Initialize variables
  v_qq   = Zero
  ef_qd  = Zero
  dv_qq  = Zero
  def_qd = Zero
    
  call electrostatics(0,0,0,v_qq,ef_qd,dv_qq,def_qd)
  call electrostatics(0,1,0,v_qq,ef_qd,dv_qq,def_qd)

!  call print_matrix(.true.,'VMM:',mm_atoms,ld_cart,mm_atoms,ld_cart,transpose(v_qq))               
!  call print_matrix(.true.,'EMM 1:',pol_atoms,3,pol_atoms,3,transpose(ef_qd(:,:,1)))               
!  call print_matrix(.true.,'EMM 2:',pol_atoms,3,pol_atoms,3,transpose(ef_qd(:,:,2)))               

end subroutine 


subroutine do_qmmm(v_qmm_,ef_qmd_,n1,n2,n3,n4)
  use precision
  use mmpol
  ! Compute polarization and QM-MM energy

  implicit none
  ! real(kind=rp), intent(in) :: v_qmm(ld_cart,mm_atoms), ef_qmd(3,pol_atoms,n_ipd)
  integer(kind=ip), intent(in) :: n1,n2,n3,n4
  real(kind=rp), intent(in) :: v_qmm_(n1,n2), ef_qmd_(3,n3,n4)

  !call print_matrix(.true.,'VQM:',mm_atoms,ld_cart,mm_atoms,ld_cart,transpose(v_qmm))
  !call print_matrix(.true.,'EQM 1:',pol_atoms,3,pol_atoms,3,transpose(ef_qmd(:,:,1))) 
  !call print_matrix(.true.,'EQM 2:',pol_atoms,3,pol_atoms,3,transpose(ef_qmd(:,:,2))) 

  ! Initialize variables
  ipd = Zero

  ! Compute polarization
  nmax = 200
  !convergence = 5.0E-10
  call polarization(solver,ef_qd+ef_qmd_,ipd)                   ! - jacobi interation solver
  !call polarization(1,ef_qd+ef_qmd,ipd) 

end subroutine

subroutine restart()
  use precision
  use mmpol 

  implicit none

  v_qq   = Zero
  ef_qd  = Zero
  dv_qq  = Zero
  def_qd = Zero
  ipd    = Zero

end subroutine

  


subroutine get_energy(EMM,EPol)
  use precision
  use mmpol
  ! Get the energy

  implicit none
  real(kind=rp), intent(out) :: EMM, EPol

  call energy(0,EMM)
  call energy(1,EPol)

end subroutine



