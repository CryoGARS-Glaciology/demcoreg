#! /bin/bash

#David Shean
#dshean@gmail.com

#This will co-register a large batch of DEMs

#Run tpfe1 or bro node
#To check out devel bro node:
#qsub ~/bin/devel.pbs
#cd topdir

#njobs=12
njobs=4
#Default is for all WV/GE/QB subdir
list_32m=$(ls -Sr *00/dem*/*-DEM_32m.tif)
list_dir=$(ls -Sr *00/dem*/*-DEM_32m.tif | awk -F'/' '{print $1}')

list_32m=$(ls -Sr $(cat incomplete_killed.txt | sed 's#$#/dem*/*-DEM_32m.tif#' | grep -v WV02_20150702_103001004453A700_10300100456F4A00))

#If we have existing orthoimages, compute top-of-atmosphere reflectance 
#Uses toa.sh, toa.py, and dglib from https://github.com/dshean/dgtools 
#parallel --jobs 16 --delay 2 'toa.sh {}' ::: $list_dir

#Clean up existing masks
#rm */*/*-DEM_32m_ref.tif */*/*-DEM_32m_*mask.tif */*/*-DEM_32m_*perc.tif
#rm */*/conus_lidar*

#Now create masks for each 32m DEM
#Check settings for dem_mask - MODSCAG, SNODAS, TOA, etc.
#parallel --jobs $njobs --delay 1 'dem_mask.py --toa {}' ::: $list_32m

#Clean up existing pc_align runs
#rm -r */*/*align */*/*trans.tif */*/*trans_dz_eul.tif 

#Do the co-registration
#set pc_align_wrapper threads to 2 or 4
#set pc_align-wrapper max displacement
list_2m=$(echo $list_32m | sed 's/-DEM_32m.tif/-DEM_2m.tif/g')
parallel_log=dem_coreg_log
parallel --progress --results $parallel_log -j $njobs --delay 3 'dem_coreg.sh {}' ::: $list_2m

#Now create new weighted average mosaics, burn into reference DEM, and rerun the co-registration
