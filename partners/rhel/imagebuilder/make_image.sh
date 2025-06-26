# Resource group name 
sigResourceGroup=RHEL-imagebuilder
# Datacenter location - West US 2 in this example
location=westus2
# Additional region to replicate the image to - East US in this example
additionalregion=eastus
# Name of the Azure Compute Gallery
sigName=RHEL_hpc_gallery
# Name of the image definition to be created
imageDefName=RHEL-hpc
# Reference name in the image distribution metadata
runOutputName=RHEL-hpc-SIG

subscriptionID=$(az account show --query id --output tsv)

az group create -n $sigResourceGroup -l $location

az sig create \
    -g $sigResourceGroup \
    --gallery-name $sigName

az sig image-definition create \
   -g $sigResourceGroup \
   --gallery-name $sigName \
   --gallery-image-definition $imageDefName \
   --hyper-v-generation V2 \
   --publisher myRHEL \
   --offer myRHELhpc \
   --sku 8.10-hpc \
   --os-type Linux



# Create user-assigned identity for VM Image Builder to access the storage account where the script is stored
identityName=RHEL_UserId
az identity create -g $sigResourceGroup -n $identityName

# Get the identity ID
imgBuilderCliId=$(az identity show -g $sigResourceGroup -n $identityName --query clientId -o tsv)

# Get the user identity URI that's needed for the template
imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$sigResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

echo Sleeping 30 seconds to allow Identity to settle
sleep 30

# Grant a role definition to the user-assigned identity
az role assignment create \
    --assignee $imgBuilderCliId \
    --role "Contributor" \
    --scope /subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup
# do manually if this failes...

# prep image template
rm RHEL-hpc-sig.json
cp RHEL-hpc-sig-template.json RHEL-hpc-sig.json
sed -i -e "s/<subscriptionID>/$subscriptionID/g" RHEL-hpc-sig.json
sed -i -e "s/<rgName>/$sigResourceGroup/g" RHEL-hpc-sig.json
sed -i -e "s/<imageDefName>/$imageDefName/g" RHEL-hpc-sig.json
sed -i -e "s/<sharedImageGalName>/$sigName/g" RHEL-hpc-sig.json
sed -i -e "s/<region1>/$location/g" RHEL-hpc-sig.json
sed -i -e "s/<region2>/$additionalregion/g" RHEL-hpc-sig.json
sed -i -e "s/<runOutputName>/$runOutputName/g" RHEL-hpc-sig.json
sed -i -e "s%<imgBuilderId>%$imgBuilderId%g" RHEL-hpc-sig.json

ImageTemplate="RHEL-hpc-"$(date +'%s')
az resource create \
    --resource-group $sigResourceGroup \
    --properties @RHEL-hpc-sig.json \
    --is-full-object \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n $ImageTemplate

az resource invoke-action \
     --resource-group $sigResourceGroup \
     --resource-type  Microsoft.VirtualMachineImages/imageTemplates \
     -n $ImageTemplate \
     --action Run


