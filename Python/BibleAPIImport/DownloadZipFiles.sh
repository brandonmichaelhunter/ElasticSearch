#!/bin/bash

ZIP_DIR_NAME="ZipFiles"

# A list of zip files to download.
zipFilesList=("http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/AB.zip" 
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ABP.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ACV.zip" 
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/AKJV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ASV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/BBE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/BWE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/CPDV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Common.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/DRC.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Darby.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/EMTV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ESV2001.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ESV2011.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Etheridge.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Geneva1599.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Godbey.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/GodsWord.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/ISV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/JPS.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Jubilee2000.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/KJV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/KJVA.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/KJVPCE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/LEB.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/LITV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/LO.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Leeser.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/MKJV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Montgomery.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Murdock.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/NETfree.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/NETtext.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/NHEB.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/NHEBJE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/NHEBME.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Noyes.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/OEB.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/OEBcth.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/OrthJBC.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/RKJNT.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/RNKJV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/RWebster.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Rotherham.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/SPE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Twenty.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Tyndale.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/UKJV.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/WEB.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/WEBBE.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/WEBME.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Webster.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Weymouth.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/Worsley.zip"
"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/YLT.zip")

# Create the directory ZipFiles
mkdir $ZIP_DIR_NAME

# Begin evaluating the list
for zipUrl in "${zipFilesList[@]}"
do
  zipFullFileName=$(basename $zipUrl)
  zipFileName="${zipFullFileName%.*}"
  echo "Downloading File: $zipFullFileName"

  # Download the zip file
  wget -P $ZIP_DIR_NAME $zipUrl 
  
  # Execute a python script to extract the bible from the zip file and convert it into a JSON file.
  echo "Executing python script on $zipFullFileName to extract bible data into a json file."
  python3 sword_to_json.py --source_file "$ZIP_DIR_NAME/$zipFullFileName" --bible_version "$zipFileName" --output_file "$zipFileName.json"
  echo "Script completed"
done

