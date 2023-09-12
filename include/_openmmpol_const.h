#ifndef _OPENMMPOL_CONST
#define _OPENMMPOL_CONST

#define OMMP_VERBOSE_DEBUG 3
#define OMMP_VERBOSE_HIGH 2 
#define OMMP_VERBOSE_LOW 1 
#define OMMP_VERBOSE_NONE 0
#define OMMP_VERBOSE_DEFAULT OMMP_VERBOSE_LOW

#define OMMP_FF_AMOEBA 1
#define OMMP_FF_WANG_AL 0 
#define OMMP_FF_WANG_DL 0 
#define OMMP_FF_AMBER 0
#define OMMP_FF_UNKNOWN -1

#define OMMP_SOLVER_NONE 0
#define OMMP_SOLVER_CG 1
#define OMMP_SOLVER_DIIS 2
#define OMMP_SOLVER_INVERSION 3
#define OMMP_SOLVER_DEFAULT OMMP_SOLVER_CG

#define OMMP_MATV_NONE 0
#define OMMP_MATV_INCORE 1
#define OMMP_MATV_DIRECT 2
#define OMMP_MATV_DEFAULT OMMP_MATV_DIRECT

#define OMMP_AMOEBA_D 1
#define OMMP_AMOEBA_P 2

#define OMMP_AU2KCALMOL      627.5096080306
#define OMMP_FORT_AU2KCALMOL 627.5096080306_rp
#define OMMP_KCALMOL2AU      1.59360109742136e-3
#define OMMP_FORT_KCALMOL2AU 1.59360109742136e-3_rp
#define OMMP_ANG2AU      1.8897261245650
#define OMMP_FORT_ANG2AU 1.8897261245650_rp
#define OMMP_VERSION_STRING "${OMMP_VERSION}"

#define OMMP_DEFAULT_LA_DIST 1.1*OMMP_ANG2AU
#define OMMP_DEFAULT_LA_N_EEL_REMOVE 2

#define OMMP_DEFAULT_NL_CUTOFF -1.0
#define OMMP_DEFAULT_NL_SUB 2

#define OMMP_STR_CHAR_MAX 4096
#endif
