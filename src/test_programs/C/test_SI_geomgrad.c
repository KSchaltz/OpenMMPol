#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "openmmpol.h"

void ana_grd_print(OMMP_SYSTEM_PRT sys,
                  void (*grad_f)(OMMP_SYSTEM_PRT, double *),
                  const char *name){
    
    int mm_atoms = ommp_get_mm_atoms(sys);
    
    double *_grad_ana = (double *) malloc(sizeof(double) * 3 * mm_atoms);
    double **grad_ana = (double **) malloc(sizeof(double *) * mm_atoms);
    char msg[OMMP_STR_CHAR_MAX];

    for(int i = 0; i < mm_atoms; i++){
        grad_ana[i] = &(_grad_ana[i*3]);
        for(int j=0; j < 3; j++)
            grad_ana[i][j] = 0.0;
    }

    grad_f(sys, _grad_ana);
   
    sprintf(msg, "Grad %s", name);
    ommp_message(msg, OMMP_VERBOSE_NONE, "TEST-OUT");
    
    for(int i = 0; i < mm_atoms; i++){
        sprintf(msg, "MM:%-8d %+20.8g %+20.8g %+20.8g", i,
                grad_ana[i][0]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana[i][1]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana[i][2]*OMMP_AU2KCALMOL*OMMP_ANG2AU);
        ommp_message(msg, OMMP_VERBOSE_NONE, "TEST-OUT");
    }
    ommp_message("", OMMP_VERBOSE_NONE, "TEST-OUT");
}

void ana_grd_print_qmmm(OMMP_SYSTEM_PRT sys,
                        OMMP_QM_HELPER_PRT qmh,
                        OMMP_SYSTEM_PRT qm_fake,
                        void (*grad_f)(OMMP_SYSTEM_PRT, 
                                       OMMP_QM_HELPER_PRT, 
                                       OMMP_SYSTEM_PRT,
                                       double *, double *),
                        const char *name){
    char msg[OMMP_STR_CHAR_MAX];
    
    int mm_atoms = ommp_get_mm_atoms(sys);
    double *_grad_ana_mm = (double *) malloc(sizeof(double) * 3 * mm_atoms);
    double **grad_ana_mm = (double **) malloc(sizeof(double *) * mm_atoms);
    for(int i = 0; i < mm_atoms; i++){
        grad_ana_mm[i] = &(_grad_ana_mm[i*3]);
        for(int j=0; j < 3; j++)
            grad_ana_mm[i][j] = 0.0;
    }
    
    int qm_atoms = ommp_qm_helper_get_qm_atoms(qmh);
    double *_grad_ana_qm = (double *) malloc(sizeof(double) * 3 * qm_atoms);
    double **grad_ana_qm = (double **) malloc(sizeof(double *) * qm_atoms);
    for(int i = 0; i < qm_atoms; i++){
        grad_ana_qm[i] = &(_grad_ana_qm[i*3]);
        for(int j=0; j < 3; j++)
            grad_ana_qm[i][j] = 0.0;
    }

    grad_f(sys, qmh, qm_fake, _grad_ana_mm, _grad_ana_qm);
   
    sprintf(msg, "Grad %s", name);
    ommp_message(msg, OMMP_VERBOSE_NONE, "TEST-OUT");
    
    for(int i = 0; i < mm_atoms; i++){
        sprintf(msg, "MM:%-8d %+20.8g %+20.8g %+20.8g", i,
                grad_ana_mm[i][0]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana_mm[i][1]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana_mm[i][2]*OMMP_AU2KCALMOL*OMMP_ANG2AU);
        ommp_message(msg, OMMP_VERBOSE_NONE, "TEST-OUT");
    }
    for(int i = 0; i < qm_atoms; i++){
        sprintf(msg, "QM:%-8d %+20.8g %+20.8g %+20.8g", i,
                grad_ana_qm[i][0]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana_qm[i][1]*OMMP_AU2KCALMOL*OMMP_ANG2AU,
                grad_ana_qm[i][2]*OMMP_AU2KCALMOL*OMMP_ANG2AU);
        ommp_message(msg, OMMP_VERBOSE_NONE, "TEST-OUT");
    }
    ommp_message("", OMMP_VERBOSE_NONE, "TEST-OUT");
}

void ommptest_qm_helper_vdw_geomgrad(OMMP_SYSTEM_PRT sys, OMMP_QM_HELPER_PRT qmh,
                                     OMMP_SYSTEM_PRT fakeqm, double *mmg, double *qmg){
    // Just for signature compliance
    ommp_qm_helper_vdw_geomgrad(qmh, sys, qmg, mmg);
}

void ommptest_fakeqm_internal_geomgrad(OMMP_SYSTEM_PRT sys, OMMP_QM_HELPER_PRT qmh,
                                     OMMP_SYSTEM_PRT fakeqm, double *mmg, double *qmg){
    // Compute derivatives of internal "QM" geometry under the assumption that MM 
    // electric field does not interact with "QM" static multipoles
    ommp_full_geomgrad(fakeqm, qmg);
}

void ommptest_fakeqm_linkatom_geomgrad(OMMP_SYSTEM_PRT sys, OMMP_QM_HELPER_PRT qmh,
                                       OMMP_SYSTEM_PRT fakeqm, double *mmg, double *qmg){
    int qm_atoms = ommp_qm_helper_get_qm_atoms(qmh);
    int mm_atoms = ommp_get_mm_atoms(sys);
    double *oldgrd = (double *) malloc(sizeof(double) * 3 * qm_atoms);
    ommp_qm_helper_vdw_geomgrad(qmh, sys, qmg, mmg);
    ommp_full_geomgrad(fakeqm, oldgrd);
    for(int i=0; i < 3 * qm_atoms; i++) oldgrd[i] += qmg[i]; // Remember, array are reset
    ommp_qm_helper_link_atom_geomgrad(qmh, sys, qmg, mmg, oldgrd);
    free(oldgrd);
}

void ommptest_totalqmmm_geomgrad(OMMP_SYSTEM_PRT sys, OMMP_QM_HELPER_PRT qmh,
                                 OMMP_SYSTEM_PRT fakeqm, double *mmg, double *qmg){
    int qm_atoms = ommp_qm_helper_get_qm_atoms(qmh);
    int mm_atoms = ommp_get_mm_atoms(sys);

    double *oldgrd_mm = (double *) malloc(sizeof(double) * 3 * mm_atoms);
    double *oldgrd_qm = (double *) malloc(sizeof(double) * 3 * qm_atoms);
    
    ommp_qm_helper_vdw_geomgrad(qmh, sys, oldgrd_qm, oldgrd_mm);
    for(int i=0; i < 3 * qm_atoms; i++) qmg[i] += oldgrd_qm[i];
    for(int i=0; i < 3 * mm_atoms; i++) mmg[i] += oldgrd_mm[i];
    ommp_full_geomgrad(fakeqm, oldgrd_qm);
    ommp_full_geomgrad(sys, oldgrd_mm);
    for(int i=0; i < 3 * qm_atoms; i++) qmg[i] += oldgrd_qm[i];
    for(int i=0; i < 3 * mm_atoms; i++) mmg[i] += oldgrd_mm[i];
    
    ommp_qm_helper_link_atom_geomgrad(qmh, sys, oldgrd_qm, oldgrd_mm, qmg);
    for(int i=0; i < 3 * qm_atoms; i++) qmg[i] += oldgrd_qm[i];
    for(int i=0; i < 3 * mm_atoms; i++) mmg[i] += oldgrd_mm[i];
    
    free(oldgrd_mm);
    free(oldgrd_qm);
}

int main(int argc, char **argv){
    if(argc != 2){
        printf("Syntax expected\n");
        printf("    $ test_SI_geomgrad.exe <JSON FILE>\n");
        return 0;
    }
    
    OMMP_SYSTEM_PRT my_system, fake_qm;
    OMMP_QM_HELPER_PRT my_qmh;
    ommp_smartinput(argv[1], &my_system, &my_qmh);
    
    bool use_qm, use_fake_qm;
    
    if(my_qmh != NULL){
        // A QM part is present!
        use_qm = true;

        if(ommp_use_linkatoms(my_system)){
            // Since LA are used, I have to create a 
            // fake system for QM in order to have the
            // complete energy; parameters should be set 
            // anyway.
            use_fake_qm = true;
        }
    }

    if(use_fake_qm){
        // Cherrypick the parameter file use for QM from
        // the smart input
        char *prm_file, addr[] = "qm/prm_file/path";
        ommp_smartimput_cpstr(argv[1], addr, &prm_file);
        //Create the fake qm system
        fake_qm = ommp_system_from_qm_helper(my_qmh, prm_file);
        // In order to make a safe interaction, remove all the polarizabilities
        // on the fake qm system
        int natm = ommp_get_pol_atoms(fake_qm);
        int32_t *nopol = malloc(sizeof(int32_t) * natm);
        for(int j=0; j < natm; j++)
            nopol[j] = j;
        ommp_turn_pol_off(fake_qm, natm, nopol);
        free(nopol);
    }

    ana_grd_print(my_system, ommp_fixedelec_geomgrad, "EM");
    ana_grd_print(my_system, ommp_polelec_geomgrad, "EP");
    ana_grd_print(my_system, ommp_vdw_geomgrad, "EV");
    ana_grd_print(my_system, ommp_bond_geomgrad, "EB");
    ana_grd_print(my_system, ommp_angle_geomgrad, "EA");
    ana_grd_print(my_system, ommp_strbnd_geomgrad, "EBA");
    ana_grd_print(my_system, ommp_urey_geomgrad, "EUB");
    ana_grd_print(my_system, ommp_opb_geomgrad, "EOPB");
    ana_grd_print(my_system, ommp_pitors_geomgrad, "EPT");
    ana_grd_print(my_system, ommp_torsion_geomgrad, "ET");
    ana_grd_print(my_system, ommp_tortor_geomgrad, "ETT");
    ana_grd_print(my_system, ommp_imptorsion_geomgrad, "EIT");
    ana_grd_print(my_system, ommp_strtor_geomgrad, "EBT");
    ana_grd_print(my_system, ommp_angtor_geomgrad, "EAT");
    if(use_qm){
        ana_grd_print_qmmm(my_system, my_qmh, fake_qm,
                           ommptest_qm_helper_vdw_geomgrad, "EVQMMM");
        if(use_fake_qm){
            ana_grd_print_qmmm(my_system, my_qmh, fake_qm,
                               ommptest_fakeqm_internal_geomgrad, "EQM");
            ana_grd_print_qmmm(my_system, my_qmh, fake_qm,
                               ommptest_fakeqm_linkatom_geomgrad, "ELA");
        }
        ana_grd_print_qmmm(my_system, my_qmh, fake_qm,
                            ommptest_totalqmmm_geomgrad, "ETOT");
    }
    else{
        ana_grd_print(my_system, ommp_full_geomgrad, "ETOT");
    }
    
    if(my_qmh != NULL) ommp_terminate_qm_helper(my_qmh);
    ommp_terminate(my_system);
    
    return 0;
}
