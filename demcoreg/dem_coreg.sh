#! /bin/bash 

#David Shean
#dshean@gmail.com

#This will co-register a single DEM
#See dem_coreg_all.sh for batch processing

#Input should be highest res version of DEM (i.e., DEM_2m.tif)
dem=$1

if [ ! -e $dem ] ; then
    echo "Unable to find source DEM: $dem"
    exit
fi

#Define the reference DEM
#Need to create vrt with 1 arcsec over areas where 1/3 is not avail
#1-arcsec NED (30 m) for CONUS
#ref=/nobackup/deshean/rpcdem/ned1/ned1_tiles_glac24k_115kmbuff.vrt
#1/3-arcsec NED (10 m) for CONUS
#ref=/nobackup/deshean/rpcdem/ned13/ned13_tiles_glac24k_115kmbuff.vrt
#1-arcsec SRTM (30 m) for HMA
#ref=/nobackup/deshean/rpcdem/hma/srtm1/hma_srtm_gl1.vrt
#1-m lidar vrt
ref=/nobackup/deshean/rpcdem/lidar/conus_lidar_1m.vrt

if [ ! -e $ref ] ; then
    echo "Unable to find ref DEM: $ref"
    exit
fi

demdir=$(dirname $dem)
dembase=$(basename $dem)
#This will be pc_align output directory
outdir=${dembase%.*}_grid_align
dembase=$(echo $dembase | awk -F'-' '{print $1}')

#This is DEM_32m reference mask output by dem_mask.py
dem_mask=$demdir/${dembase}-DEM_32m_ref.tif

if [ ! -e $dem_mask ] ; then
    echo "Unable to find reference DEM mask, need to run dem_mask.py"
    exit
fi

refdem=$demdir/$(basename $ref)
refdem=${refdem%.*}_warp.tif
if [ ! -e $refdem ] ; then
    #Clip the reference DEM to the DEM_32m extent
    echo "Clipping high-res reference DEM to appropriate extent"
    warptool.py -te $dem -tr $ref -t_srs $dem -outdir $demdir $ref
fi

#Check if refdem has valid pixels

#This avoids writing another copy of ref, but is slower
#NOTE: assumes projection of $dem and $ref are identical.  Need to implement better get_extent with -t_srs option
#dem_extent=$(~/src/demtools/get_extent.py $dem)
#echo "Creating vrt of high-res reference DEM clipped to appropriate extent"
#gdalbuildvrt -tr 1 1 -te $dem_extent -tap -r nearest ${refdem%.*}_warp.vrt $ref
#refdem=${refdem%.*}_warp.vrt

#Mask the ref using valid pixels in DEM_32m_ref.tif product
refdem_masked=${refdem%.*}_masked.tif
if [ ! -e $refdem_masked ] ; then
    echo "Applying low-res mask to high-res reference DEM"
    apply_mask.py -extent intersection $refdem $dem_mask
fi

#Check if refdem_masked has valid pixels

if [ -e $refdem_masked ] ; then
    #point-to-point
    pc_align_wrapper.sh $refdem_masked $dem

    cd $demdir
    if ls -t $outdir/*DEM.tif 1> /dev/null 2>&1 ; then 
        log=$(ls -t $outdir/*.log | head -1)
        if grep -q 'Translation vector' $log ; then
            apply_dem_translation.py ${dembase}-DEM_32m.tif $log
            apply_dem_translation.py ${dembase}-DEM_8m.tif $log
            ln -sf $outdir/*DEM.tif ${dembase}-DEM_2m_trans.tif
            #compute_dh.py $(basename $refdem) ${dembase}-DEM_8m_trans.tif
        fi
    fi
fi
