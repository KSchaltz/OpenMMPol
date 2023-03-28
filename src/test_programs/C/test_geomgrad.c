#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "openmmpol.h"

int countLines(char *fin){
    FILE *fp = fopen(fin, "r");
    
    char c;
    int lines = 1;

    if(fp == NULL) return 0;

    do{
        c = fgetc(fp);
        if(c == '\n') lines++;
    }while(c != EOF);

    fclose(fp);
  
    return lines - 1;
}

double **read_ef(char *fin){
    double **ef;
    
    int pol_atoms = countLines(fin);

    ef = (double **) malloc(sizeof(double *) * 3 * pol_atoms);

    FILE *fp = fopen(fin, "r");
    for(int i =0; i < pol_atoms; i++){
        ef[i] = (double *) malloc(sizeof(double) * 3);
        fscanf(fp, "%lf %lf %lf", &(ef[i][0]), &(ef[i][1]),  &(ef[i][2]));
    }
    fclose(fp);

    return ef;
}

int main(int argc, char **argv){
    if(argc != 4 && argc != 3){
        printf("Syntax expected\n");
        printf("    $ test_geomgrad.exe <INPUT FILE> <OUTPUT FILE>\n");
        return 0;
    }
    
    int pol_atoms, mm_atoms, retcode=0;
    double *electric_field;
    double **external_ef, **grad_ana, *_grad_ana;
    int32_t *polar_mm;

    OMMP_SYSTEM_PRT my_system = ommp_init_mmp(argv[1]);
    ommp_set_verbose(OMMP_VERBOSE_NONE);
    pol_atoms = ommp_get_pol_atoms(my_system);
    mm_atoms = ommp_get_mm_atoms(my_system);
    
    electric_field = (double *) malloc(sizeof(double) * 3 * pol_atoms);
    polar_mm = (int32_t *) ommp_get_polar_mm(my_system);

    _grad_ana = (double *) malloc(sizeof(double) * 3 * mm_atoms);
    grad_ana = (double **) malloc(sizeof(double *) * mm_atoms);
    for(int i = 0; i < mm_atoms; i++){
        grad_ana[i] = &(_grad_ana[i*3]);
        for(int j=0; j < 3; j++)
            grad_ana[i][j] = 0.0;
    }
   
    if(argc == 4){
        printf("Currently unsupported");
        return 0;
        external_ef = read_ef(argv[3]);
    }

    for(int j = 0; j < pol_atoms; j++)
        for(int k = 0; k < 3; k++)
            if(argc == 4)
                electric_field[j*3+k] = external_ef[polar_mm[j]][k];
            else
                electric_field[j*3+k] = 0.0;
    
    FILE *fp = fopen(argv[2], "w+");
    
    ommp_fixedelec_geomgrad(my_system, _grad_ana);
    
    fprintf(fp, "Grad EM\n");
    for(int i = 0; i < mm_atoms; i++){
        for(int j=0; j < 3; j++)
            fprintf(fp, "%+12.8g ", grad_ana[i][j]);
        fprintf(fp, "\n");
    }
    fprintf(fp, "\n");

    for(int i = 0; i < mm_atoms; i++)
        for(int j=0; j < 3; j++)
            grad_ana[i][j] = 0.0;
    
    ommp_polelec_geomgrad(my_system, _grad_ana);
   
    fprintf(fp, "Grad EP\n");
    for(int i = 0; i < mm_atoms; i++){
        for(int j=0; j < 3; j++)
            fprintf(fp, "%+12.8g ", grad_ana[i][j]);
        fprintf(fp, "\n");
    }
    fprintf(fp, "\n");

    fclose(fp);
    free(electric_field);
    ommp_terminate(my_system);
    
    return retcode;
}

