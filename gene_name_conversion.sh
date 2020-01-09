sudo apt-get update
sudo apt-get -y install gzip tar wget unzip curl build-essential python python-dev python3 python3-dev libboost-dev perl zlib1g-dev default-jre default-jdk cmake libtbb-dev python-pip python3-pip
pip install numpy
pip3 install numpy
#Installing BLAST
wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.9.0+-src.tar.gz
tar -zxvf ncbi-blast-2.9.0+-src.tar.gz
rm -r ncbi-blast-2.9.0+-src.tar.gz
cd ncbi-blast-2.9.0+-src
cd c++
./configure
cd ReleaseMT/build
make all_r
cd ../bin
sudo ln -s $(pwd)/* /usr/local/bin/
cd ~
#Making directories and downloading the genomes
mkdir old_genome
mkdir new_genome
cd new_genome
wget http://silkbase.ab.a.u-tokyo.ac.jp/pub/Bomo_gene_models_nucl.fa.gz
gunzip Bomo_gene_models_nucl.fa.gz
mv Bomo_gene_models_nucl.fa bmnew.fa
#Making a database to search against
makeblastdb -in 'bmnew.fa' -dbtype 'nucl' -parse_seqids -title 'bmnewdb'
#Download the other genes to create a matching annotation system
cd ..
cd old_genome
wget http://sgp.dna.affrc.go.jp/ComprehensiveGeneSet/files/GenesetA.nt.fasta.zip
unzip GenesetA.nt.fasta.zip
rm -r GenesetA.nt.fasta.zip
#Query the DB to create an annotation of sorts
blastn -db "../new_genome/bmnew.fa" -query GenesetA.nt.fasta -out results.out
#Uploaded this script to create a simple annotation scheme
wget https://raw.githubusercontent.com/NKalavros/random-scripts/master/get_accessions_from_blast
python3 get_accessions_from_blast
cd ..
#Install gsutil to interact with the bucket
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get -y install apt-transport-https ca-certificates
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get -y update && sudo apt-get -y install google-cloud-sdk
#Enter the needed stuff to initialize and obtain access to the files
gcloud init
#Download FASTQ files from the bucket, make sure to change the permissions of the projects users to system admin so that you can download the data
mkdir processed_fastq
gcloud auth login
gsutil -m cp gs://rna-seq-bombyx-mori/dedos_project/HybridStat/fastq/* /root/processed_fastq/
#Download and compile STAR
wget https://github.com/alexdobin/STAR/archive/2.7.2a.tar.gz
tar -xzf 2.7.2a.tar.gz
rm -r 2.7.2a.tar.gz
cd STAR-2.7.2a
cd source
make STAR
sudo ln -s $(pwd)/STAR /usr/local/bin/
cd ../..
#Make a suffix array from the new genome
cd new_genome
wget http://silkbase.ab.a.u-tokyo.ac.jp/pub/Bomo_genome_assembly.fa.gz
gunzip Bomo_genome_assembly.fa.gz
#Get the annotation file as well
wget http://silkbase.ab.a.u-tokyo.ac.jp/pub/Bomo_gene_models.gff3.gz
gunzip Bomo_gene_models.gff3.gz
#Create suffix array with 107 gene length (read_length post processing -1)
#This command is meant to delete unneeded files if by chance I create them rm -r _STARtmp chrLength.txt chrName.txt chrNameLength.txt chrStart.txt Log.out SA_15 If nothing goes wrong, this takes 5 minutes
STAR --runThreadN 16 --runMode genomeGenerate --genomeDir $(pwd) --genomeFastaFiles $(pwd)/Bomo_genome_assembly.fa --sjdbGTFfile $(pwd)/Bomo_gene_models.gff3 --sjdbOverhang 107 --sjdbGTFtagExonParentTranscript Parent --genomeSAindexNbases 13
cd ..
#Begin running mapping jobs
echo 'kernel.shmmax = 5000000' >> /etc/sysctl.conf
echo 'kernel.shmall = 1200' >> /etc/sysctl.conf
mkdir aligned_reads
cd processed_fastq

#Begin the big job for day 0
STAR --runThreadN 16 --genomeDir /root/new_genome --readFilesIn C6V61ANXX_102593-001-001_GCCAAT_L001_R1.fastq.gz,C6V61ANXX_102593-001-002_CAGATC_L001_R1.fastq.gz,C6V61ANXX_102593-001-003_ACTTGA_L001_R1.fastq.gz C6V61ANXX_102593-001-001_GCCAAT_L001_R2.fastq.gz,C6V61ANXX_102593-001-002_CAGATC_L001_R2.fastq.gz,C6V61ANXX_102593-001-003_ACTTGA_L001_R2.fastq.gz --readFilesCommand gunzip -c --outFilterType BySJout --outFilterMultimapNmax 25 --alignSJoverhangMin 4 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --genomeLoad LoadAndKeep --outFileNamePrefix /root/aligned_reads/aligned_day_zero
#Make a second pass through the files with more splice junctions, just to make sure we have the most sensitivity we can
STAR --runThreadN 16 --genomeDir /root/new_genome --readFilesIn C6V61ANXX_102593-001-001_GCCAAT_L001_R1.fastq.gz,C6V61ANXX_102593-001-002_CAGATC_L001_R1.fastq.gz,C6V61ANXX_102593-001-003_ACTTGA_L001_R1.fastq.gz C6V61ANXX_102593-001-001_GCCAAT_L001_R2.fastq.gz,C6V61ANXX_102593-001-002_CAGATC_L001_R2.fastq.gz,C6V61ANXX_102593-001-003_ACTTGA_L001_R2.fastq.gz --readFilesCommand gunzip -c --outFilterType BySJout --outFilterMultimapNmax 25 --alignSJoverhangMin 4 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --genomeLoad NoSharedMemory --outFileNamePrefix /root/aligned_reads/day_zero_second_pass --sjdbFileChrStartEnd /root/aligned_reads/aligned_day_zeroSJ.out.tab
#Same for day 6
STAR --runThreadN 16 --genomeDir /root/new_genome --readFilesIn C6V61ANXX_102593-001-004_GATCAG_L001_R1.fastq.gz,C6V61ANXX_102593-001-005_TAGCTT_L001_R1.fastq.gz,C6V61ANXX_102593-001-006_CTTGTA_L001_R1.fastq.gz
C6V61ANXX_102593-001-004_GATCAG_L001_R2.fastq.gz,C6V61ANXX_102593-001-005_TAGCTT_L001_R2.fastq.gz,C6V61ANXX_102593-001-006_CTTGTA_L001_R2.fastq.gz --readFilesCommand gunzip -c --outFilterType BySJout --outFilterMultimapNmax 25 --alignSJoverhangMin 4 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --genomeLoad LoadAndKeep --outFileNamePrefix /root/aligned_reads/aligned_day_six
STAR --runThreadN 16 --genomeDir /root/new_genome --readFilesIn C6V61ANXX_102593-001-004_GATCAG_L001_R1.fastq.gz,C6V61ANXX_102593-001-005_TAGCTT_L001_R1.fastq.gz,C6V61ANXX_102593-001-006_CTTGTA_L001_R1.fastq.gz
C6V61ANXX_102593-001-004_GATCAG_L001_R2.fastq.gz,C6V61ANXX_102593-001-005_TAGCTT_L001_R2.fastq.gz,C6V61ANXX_102593-001-006_CTTGTA_L001_R2.fastq.gz --readFilesCommand gunzip -c --outFilterType BySJout --outFilterMultimapNmax 25 --alignSJoverhangMin 4 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 --genomeLoad NoSharedMemory --outFileNamePrefix /root/aligned_reads/day_zero_second_pass --sjdbFileChrStartEnd /root/aligned_reads/aligned_day_sixSJ.out.tab
cd ..
#Uploading those to the bucket
gsutil -m cp -r /root/aligned_reads/ gs://rna-seq-bombyx-mori/dedos_project/aligned_reads/

##Download TBB
#wget https://github.com/intel/tbb/archive/2019_U8.tar.gz
#tar -zxvf 2019_U8.tar.gz
#rm -r 2019_U8.tar.gz
#cd tbb-2019_U8
#make
#echo "export TBB_INSTALL_DIR=/root/tbb-2019-U8" >> /root/.bashrc
#echo "export TBB_INCLUDE=/root/tbb-2019-U8/include" >> /root/.bashrc
#echo "export TBB_LIBRARY_RELEASE=/root/tbb-2019-U8/build/linux_intel64_gcc_cc7.4.0_libc2.27_kernel4.15.0_release" >> /root/.bashrc
#echo "export TBB_LIBRARY_DEBUG=/root/tbb-2019-U8/build/linux_intel64_gcc_cc7.4.0_libc2.27_kernel4.15.0_debug" >> /root/.bashrc
#Download Bowtie2
curl -L https://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.3.5.1/bowtie2-2.3.5.1-source.zip/download --output bowtie2-2.3.5.1-source.zip
unzip bowtie2-2.3.5.1-source.zip
rm bowtie2-2.3.5.1-source.zip
cd bowtie2-2.3.5.1
make
make install
cd ..
#Download Jellyfish
wget https://github.com/gmarcais/Jellyfish/archive/v2.3.0.tar.gz
tar -zxvf v2.3.0.tar.gz
rm v2.3.0.tar.gz
#Install some necessary packages
sudo apt-get -y install autoconf automake libtool gettext pkg-config ruby
gem install yaggo
cd Jellyfish-2.3.0
autoreconf -i
./configure
make -j 4
make install
cd ..
#Download and install Salmon
wget https://github.com/COMBINE-lab/salmon/archive/v0.14.1.tar.gz
tar -zxvf v0.14.1.tar.gz
rm -r v0.14.1.tar.gz
#Installing Boost, doing it through salmon itself now
#wget https://dl.bintray.com/boostorg/release/1.70.0/source/boost_1_70_0.tar.gz
#tar -zxvf boost_1_70_0.tar.gz
#rm -r boost_1_70_0.tar.gz
#cd boost_1_70_0
#./bootstrap.sh
#./b2 install
#cd ..
cd salmon-0.14.1
sudo apt-get -y install bzip2 libbz2-1.0 libbz2-dev libbz2-ocaml libbz2-ocaml-dev liblzma-dev
sed -i "s|http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz|https://nchc.dl.sourceforge.net/project/bzip2/bzip2-1.0.6.tar.gz|" CMakeLists.txt
mkdir build
cd build
cmake -DFETCH_BOOST=TRUE ..
make
make install
make test
cd ../..
#Download Trinity
wget https://github.com/trinityrnaseq/trinityrnaseq/archive/Trinity-v2.8.5.tar.gz
tar -zxvf Trinity-v2.8.5.tar.gz
rm -r Trinity-v2.8.5.tar.gz
cd Trinity-v2.8.5

