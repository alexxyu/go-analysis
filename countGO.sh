#!/bin/bash
#To use: bash countGO.sh [GO Term(s)] [unique query id]
#For multiple GO terms, enter them separated by only a comma
#Example: bash countGO.sh GO:1902991,GO:1902992 test

#Must have wget installed

countGOTerms()
{
    queryid=$2

    #Download all species data in background first
    input="data/dataSpecies.txt"
    numSpecies=$(wc -l $input | awk '{print $1}')

    while read -r species; do

        goterms=$1
        dataset=$(python get_dataset.py $species)
        download_genes $dataset $goterms $species

    done < "$input"

    #Count number of genes in each species datafile
    wait
    while read -r species; do
        
        #Ensures that the relevant species data file is fully downloaded
        lastLine=$(awk '/./{line=$0} END{print line}' count/$species.fa)
        while [[ $lastLine != "[success]" ]]; do

            if [[ $lastLine == *"ERROR 500: Internal Server Error."* ]]; then
                echo "Server error thrown. Skipping current GO term."
                rm countData/count\_$queryid.txt
                exit 1
            fi

            sleep 3
            lastLine=$(awk '/./{line=$0} END{print line}' count/$species.fa)
        done

        numTerms=$(wc -l count/$species.fa | awk '{print $1}')
        numTerms=$(( numTerms - 1 ))
        echo "${numTerms}" >> countData/count\_$queryid.txt

    done < "$input"
}

download_genes()
{
    #Dataset name from Ensembl
    dataset=$1
    dataset=\"$dataset\"

    #GO terms must be separated by comma (no space)
    goterms=$2
    goterms=\"$goterms\"

    wget -b -o debug/$species.txt -O $species.fa --timeout=300 --tries=3 'http://www.ensembl.org/biomart/martservice?query=<?xml version="1.0" encoding="UTF-8"?> <!DOCTYPE Query> <Query virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "1" count = "" datasetConfigVersion = "0.6" completionStamp = "1"> <Dataset name = '$dataset' interface = "default" > <Filter name = "go_parent_term" value = '$goterms'/> <Attribute name = "ensembl_gene_id" /> </Dataset> </Query>' > /dev/null
    mv $species.fa count/$species.fa
}

convertsecs()
{
    ((h=${1}/3600))
    ((m=(${1}%3600)/60))
    ((s=${1}%60))
    printf "Elapsed time: %02d:%02d:%02d\n" $h $m $s
}

if [ $# -lt 2 ]; then
    echo "Error -- Program takes arguments as follows: "
    echo "bash countGO.sh [GO Term(s)] [unique query id]"
    exit 1
fi

start=$SECONDS
mkdir -p count
mkdir -p countData
mkdir -p debug

if [[ -e countData/count\_$2.txt ]]; then
    #echo "File already found."
    exit 1
fi

countGOTerms $1 $2

rm -rf count

end=$SECONDS
elapsed=$(( end - start ))
convertsecs $elapsed

exit 0