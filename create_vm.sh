#Download the gcloud package
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get -y install apt-transport-https ca-certificates
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get -y install google-cloud-sdk
sudo gcloud init
#Go through the login and all other such commands
#Command to create VM, translated from the google cloud console
sudo gcloud beta compute --project=key-hope-240509 instances create rna-seq-dedos --zone=europe-west1-b --machine-type=n1-standard-16 --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=522563825915-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=http-server,https-server --image=ubuntu-1804-bionic-v20190813a --image-project=ubuntu-os-cloud --boot-disk-size=1000GB --boot-disk-type=pd-standard --boot-disk-device-name=rna-seq-dedos --reservation-affinity=any
#SSH in the actual server, key is sandra
sudo gcloud beta compute --project "key-hope-240509" ssh --zone "europe-west1-b" "rna-seq-dedos"
