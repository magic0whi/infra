# Tips

## Multiple Project with Different Credentials

To swith:
```bash
gcloud config configurations activate project-0
gcloud config configurations activate project-1
gcloud config configurations activate project-2
```

## Rescue

Remove a VM but keep its boot disk
```bash
terraform state rm 'module.nodes["proteus-nixos-0"].google_compute_instance.node'
gcloud compute instances set-disk-auto-delete proteus-nixos-0 \
  --zone=us-west1-b \
  --device-name=proteus-nixos-0 \
  --no-auto-delete
```
