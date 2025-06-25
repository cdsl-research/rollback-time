# rollback-time
This repository contains the files used to record the time taken for a rollback process inside the doktor-setup.

### Contents 
- rollout_timer.sh
  - Bash script used to record the time taken for a rollback process

### Doktor Environment
For this repository, I will be using the Doktor setup inside CDSL
https://github.com/cdsl-research/doktor-v2

### rollout_timer.sh
This script tracks the parallel rollout time of multiple Kubernetes deployments across different namespaces. It's designed for the Doktor microservices architecture.

#### Defined Deployments
Inside the rollout_timer.sh, the deployments to be monitored during a rollback process has been determined.

The whole list of namespaces inside the Doktor setup can be seen as below.
```
cdsl@doktor-share-ancher:~$ kubectl get ns
NAME              STATUS   AGE
author            Active   89d
backup            Active   23d
cadvisor          Active   7d20h
default           Active   99d
elastic           Active   44d
front             Active   90d
front-admin       Active   90d
fulltext          Active   89d
istio-system      Active   98d
kafka             Active   56d
kube-node-lease   Active   99d
kube-public       Active   99d
kube-system       Active   99d
monitoring        Active   55d
okada-backup      Active   21d
paper             Active   89d
production        Active   92d
rook-ceph         Active   99d
stats             Active   90d
test              Active   99d
thumbnail         Active   89d
```
The whole list of deployments can also be seen as below.
```
cdsl@doktor-share-ancher:~$ kubectl get deployment -A
NAMESPACE      NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
author         author-app-deploy                            3/3     3            3           89d
author         author-mongo-deploy                          1/1     1            1           89d
author         author-mongo-express-deploy                  1/1     1            1           89d
front-admin    front-admin-app-deploy                       3/3     3            3           89d
front          front-app-deploy                             3/3     3            3           89d
fulltext       fulltext-app-deploy                          3/3     3            3           72d
fulltext       fulltext-elastic-deploy                      1/1     1            1           89d
fulltext       fulltext-kibana-deploy                       1/1     1            1           89d
istio-system   istio-ingressgateway                         1/1     1            1           71d
istio-system   istiod                                       1/1     1            1           98d
istio-system   jaeger                                       1/1     1            1           48d
kube-system    coredns                                      1/1     1            1           99d
kube-system    local-path-provisioner                       1/1     1            1           99d
kube-system    metrics-server                               1/1     1            1           19d
monitoring     blackbox-prometheus-blackbox-exporter        1/1     1            1           55d
paper          paper-app-deploy                             3/3     3            3           89d
paper          paper-minio-deploy                           1/1     1            1           89d
paper          paper-mongo-deploy                           1/1     1            1           89d
paper          paper-mongo-express-deploy                   1/1     1            1           89d
rook-ceph      csi-cephfsplugin-provisioner                 2/2     2            2           99d
rook-ceph      csi-rbdplugin-provisioner                    2/2     2            2           99d
rook-ceph      rook-ceph-crashcollector-doktor-m-v2         1/1     1            1           99d
rook-ceph      rook-ceph-crashcollector-doktor-worker1-v2   1/1     1            1           19d
rook-ceph      rook-ceph-crashcollector-doktor-worker2-v2   1/1     1            1           28d
rook-ceph      rook-ceph-crashcollector-doktor-worker3-v2   1/1     1            1           41d
rook-ceph      rook-ceph-exporter-doktor-m-v2               1/1     1            1           99d
rook-ceph      rook-ceph-exporter-doktor-worker1-v2         1/1     1            1           19d
rook-ceph      rook-ceph-exporter-doktor-worker2-v2         1/1     1            1           28d
rook-ceph      rook-ceph-exporter-doktor-worker3-v2         1/1     1            1           41d
rook-ceph      rook-ceph-mds-myfs-a                         1/1     1            1           99d
rook-ceph      rook-ceph-mds-myfs-b                         1/1     1            1           99d
rook-ceph      rook-ceph-mgr-a                              1/1     1            1           99d
rook-ceph      rook-ceph-mgr-b                              1/1     1            1           99d
rook-ceph      rook-ceph-mon-d                              1/1     1            1           89d
rook-ceph      rook-ceph-mon-q                              1/1     1            1           41d
rook-ceph      rook-ceph-mon-r                              1/1     1            1           32d
rook-ceph      rook-ceph-operator                           1/1     1            1           99d
rook-ceph      rook-ceph-osd-0                              1/1     1            1           99d
rook-ceph      rook-ceph-osd-1                              1/1     1            1           99d
rook-ceph      rook-ceph-osd-2                              1/1     1            1           99d
rook-ceph      rook-ceph-osd-3                              0/1     1            0           99d
rook-ceph      rook-ceph-tools                              1/1     1            1           99d
stats          stats-app-deploy                             3/3     3            3           89d
stats          stats-mongo-deploy                           1/1     1            1           89d
stats          stats-mongo-express-deploy                   1/1     1            1           89d
thumbnail      thumbnail-app-deploy                         3/3     3            3           89d
thumbnail      thumbnail-minio-deploy                       1/1     1            1           34d
```

However, inside the Doktor microservice architecture, during a rolling update/rollback process, the affected deployments will be only application pods inside 7 namespaces which are the following; 
- author
- paper
- stats
- front
- front-admin
- thumbnail
- fulltext

Inside rollout_timer.sh you can find the following part.
```
DEPLOYMENTS=(
  "author author-app-deploy"
  "paper paper-app-deploy"
  "stats stats-app-deploy"
  "front front-app-deploy"
  "front-admin front-admin-app-deploy"
  "thumbnail thumbnail-app-deploy"
  "fulltext fulltext-app-deploy"
)
```
This array lists all the application deployments inside the seven namespaces i have shown before this, each specified with a <namespace> <deployment-name> pair.

#### Log Setup
```
LOG_DIR="rollout-logs"
mkdir -p "$LOG_DIR"
```
To store the data of updating the deployments parallelly, the script will make a directory called rollout-logs to store logs from each rollout operation.

```
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/rollout_parallel_log_$TIMESTAMP.txt"
```
Then, the script will generate a timestamped log file for the current run.

#### Monitor Function
The script will monitor all of the deployments which will be updated parallelly.
```
monitor_rollout() {
  NS=$1
  DEP=$2
  TMP_FILE="$TMP_LOG_DIR/${NS}_${DEP}.log"

  START_TIME=$(date +%s)
  echo "[${NS}/${DEP}] Start: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TMP_FILE"

  kubectl rollout status deployment/"$DEP" -n "$NS" >> "$TMP_FILE" 2>&1

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo "[${NS}/${DEP}] End:   $(date '+%Y-%m-%d %H:%M:%S')" >> "$TMP_FILE"
  echo "[${NS}/${DEP}] Duration: ${DURATION} seconds" >> "$TMP_FILE"
}
```
This function will take in a namespace and deployment name which is defined earlier. It will do the following
- Records the start time
- Monitors the rollout status using ```kubectl rollout status
- Logs the start/end time and duration for each deployment inside the Log file

#### Parallel Execution
```
# Launch all monitors in background
for entry in "${DEPLOYMENTS[@]}"; do
  NS=$(echo $entry | awk '{print $1}')
  DEP=$(echo $entry | awk '{print $2}')
  monitor_rollout "$NS" "$DEP" &
done

# Wait for all background jobs to finish
wait
```
Deployments are monitored in parallel using background jobs (&). wait ensures the script halts until all monitoring jobs complete.

#### Summary and Cleanup of Log Files 
```
# Consolidate logs
echo -e "\n Rollout Summary:" >> "$LOG_FILE"
for entry in "${DEPLOYMENTS[@]}"; do
  NS=$(echo $entry | awk '{print $1}')
  DEP=$(echo $entry | awk '{print $2}')
  echo "----------------------------------------" >> "$LOG_FILE"
  cat "$TMP_LOG_DIR/${NS}_${DEP}.log" >> "$LOG_FILE"
done

echo -e "\n All rollouts completed at $(date)" >> "$LOG_FILE"
echo "Total parallel rollout time: ${TOTAL_DURATION} seconds" >> "$LOG_FILE"

# Clean up temp logs
rm -rf "$TMP_LOG_DIR"
```
After all of the rollouts are complete, the individual logs are aggregated into one summary file, and all of the previous temporary files are cleaned up.




























 
