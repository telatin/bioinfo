#!/bin/bash

set -euxo pipefail

wget "https://www.mothur.org/w/images/d/d6/MiSeqSOPData.zip"
unzip -q "MiSeqSOPData.zip" 
rm "MiSeqSOPData.zip"
