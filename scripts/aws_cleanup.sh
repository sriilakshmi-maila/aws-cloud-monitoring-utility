#!/bin/bash
# Automated AWS Cost-Optimization Utility (Dry-Run Safe)
# Audits unused EBS volumes, unattached Elastic IPs, and stale snapshots (>30 days)

REGION=${1:-"us-east-1"}
MODE=${2:-"--dry-run"}

echo "Scanning AWS Region: $REGION | Mode: $MODE"

# Check for Unattached EBS Volumes
echo "--- Checking Unattached EBS Volumes ---"
VOLUMES=$(aws ec2 describe-volumes --region "$REGION" \
  --filters Name=status,Values=available \
  --query "Volumes[*].VolumeId" --output text)

if [ -z "$VOLUMES" ]; then
  echo "No unused EBS volumes found."
else
  for VOL in $VOLUMES; do
    if [ "$MODE" == "--delete" ]; then
      aws ec2 delete-volume --region "$REGION" --volume-id "$VOL"
      echo "Deleted unused EBS volume: $VOL"
    else
      echo "[DRY-RUN] Found unused EBS volume: $VOL"
    fi
  done
fi

# Check for Unassociated Elastic IPs
echo "--- Checking Unassociated Elastic IPs ---"
EIPS=$(aws ec2 describe-addresses --region "$REGION" \
  --query "Addresses[?AssociationId==null].AllocationId" --output text)

if [ -z "$EIPS" ]; then
  echo "No unused Elastic IPs found."
else
  for ID in $EIPS; do
    if [ "$MODE" == "--delete" ]; then
      aws ec2 release-address --region "$REGION" --allocation-id "$ID"
      echo "Released unused Elastic IP: $ID"
    else
      echo "[DRY-RUN] Found unused Elastic IP: $ID"
    fi
  done
fi

# 3. Check for Stale Snapshots (Older than 30 days)
echo "--- Checking Stale EBS Snapshots (>30 days) ---"
CUTOFF_DATE=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-30d +%Y-%m-%dT%H:%M:%S)
SNAPSHOTS=$(aws ec2 describe-snapshots --region "$REGION" --owner-ids self \
  --query "Snapshots[?StartTime<='$CUTOFF_DATE'].SnapshotId" --output text)

if [ -z "$SNAPSHOTS" ]; then
  echo "No stale snapshots found."
else
  for SNAP in $SNAPSHOTS; do
    if [ "$MODE" == "--delete" ]; then
      aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$SNAP"
      echo "Deleted stale snapshot: $SNAP"
    else
      echo "[DRY-RUN] Found stale snapshot: $SNAP"
    fi
  done
fi
