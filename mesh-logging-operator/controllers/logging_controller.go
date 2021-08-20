/*
Copyright 2021.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	//appsv1 "k8s.io/api/apps/v1"
	//corev1 "k8s.io/api/core/v1"

	"encoding/hex"
	"fmt"
	v1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"strconv"

	"k8s.io/apimachinery/pkg/runtime"
	//metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	//"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/types"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/source"

	//"reflect"
	"context"
	"crypto/md5"
	loggingv1alpha1 "hkjc.org.hk/mesh/logging-operator/api/v1alpha1"
	operator "hkjc.org.hk/mesh/logging-operator/pkg/operator"
	"time"
)

// LoggingReconciler reconciles a Logging object
type LoggingReconciler struct {
	client.Client
	Scheme      *runtime.Scheme
	BasicConfig operator.BasicConfig
	BasicConst  operator.BasicConst
}

//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=loggings,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=loggings/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=loggings/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=alertpatterns,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=alertpatterns/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=alertpatterns/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=parsers,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=parsers/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=parsers/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=throttles,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=throttles/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.hk,resources=throttles/finalizers,verbs=update
//+kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps,resources=daemonsets,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Logging object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.9.2/pkg/reconcile
func (r *LoggingReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *LoggingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	ctx := context.Background()
	log := ctrllog.FromContext(ctx)

	// Schedule to doing reconcile in WatchInterval
	ticker := time.NewTicker(time.Duration(r.BasicConfig.WatchInterval) * time.Second)
	go func() {
		for range ticker.C {
			currentTimestamp := time.Now().Unix()

			// Get exist bmc forwarder microservice config and its info
			var existBmcForwarderMicroserviceConfigHash string
			var existBmcForwarderMicroserviceConfigModified int64
			existBmcForwarderConfig := &corev1.ConfigMap{}
			err := r.Get(ctx, client.ObjectKey{
				Namespace: r.BasicConfig.OperatorNamespace,
				Name:      r.BasicConst.BmcForwarderMicroserviceConfig,
			}, existBmcForwarderConfig)
			if err == nil && len(existBmcForwarderConfig.UID) > 0 {
				if existBmcForwarderConfig.ObjectMeta.Annotations != nil && len(existBmcForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation]) > 0 {
					existBmcForwarderMicroserviceConfigHash = existBmcForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation]
				}
				if existBmcForwarderConfig.ObjectMeta.Annotations != nil && len(existBmcForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation]) > 0 {
					existBmcForwarderMicroserviceConfigModified, _ = strconv.ParseInt(existBmcForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation], 10, 64)
				}
			}

			// Load current bmc forwarder microservice config and its info
			var bmcForwarderMicroserviceConfig = ""
			var alertPatterns loggingv1alpha1.AlertPatternList
			if err := r.List(ctx, &alertPatterns); err == nil {
				log.Info("Loading AlertPattern")
				alertPatternsConfig, err := alertPatterns.Load()
				if err == nil {
					bmcForwarderMicroserviceConfig = bmcForwarderMicroserviceConfig + alertPatternsConfig
				} else {
					log.Error(err, "Failed to load AlertPattern")
				}
			} else {
				log.Error(err, "Unable to list AlertPattern")
			}
			bmcForwarderConfigMD5 := md5.Sum([]byte(bmcForwarderMicroserviceConfig))
			bmcForwarderConfigHash := hex.EncodeToString(bmcForwarderConfigMD5[:])

			// Check current and exist bmcForwarderMicroserviceConfig checksum
			log.Info("Comparing hash", "existBmcForwarderMicroserviceConfigHash", existBmcForwarderMicroserviceConfigHash, "bmcForwarderConfigHash", bmcForwarderConfigHash)
			if existBmcForwarderMicroserviceConfigHash != bmcForwarderConfigHash {
				// If current and exist bmcForwarderMicroserviceConfig checksum not same
				// Create a new ConfigMap for current bmcForwarderMicroserviceConfig
				log.Info("Create configmap var for AlertPattern in namespace", "OperatorNamespace", r.BasicConfig.OperatorNamespace)
				existBmcForwarderMicroserviceConfigModified = currentTimestamp
				alertPatternConfigMap := &corev1.ConfigMap{
					ObjectMeta: metav1.ObjectMeta{
						Name:      r.BasicConst.BmcForwarderMicroserviceConfig,
						Namespace: r.BasicConfig.OperatorNamespace,
						Annotations: map[string]string{
							r.BasicConst.ChecksumAnnotation: bmcForwarderConfigHash,
							r.BasicConst.ModifiedAnnotation: strconv.FormatInt(currentTimestamp, 10),
						},
					},
					Data: map[string]string{
						"alert-pattern.conf": bmcForwarderMicroserviceConfig,
					},
				}

				// Create or update current bmcForwarderMicroserviceConfig to k8s
				log.Info("Create or update configmap resource for AlertPattern")
				if _, err := controllerutil.CreateOrUpdate(ctx, r.Client, alertPatternConfigMap, func() error {
					if alertPatternConfigMap.ObjectMeta.Annotations == nil {
						alertPatternConfigMap.ObjectMeta.Annotations = map[string]string{}
					}
					alertPatternConfigMap.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation] = bmcForwarderConfigHash
					alertPatternConfigMap.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation] = strconv.FormatInt(currentTimestamp, 10)
					alertPatternConfigMap.Data = map[string]string{
						"alert-pattern.conf": bmcForwarderMicroserviceConfig,
					}
					alertPatternConfigMap.SetOwnerReferences(nil)
					return nil
				}); err != nil {
					log.Error(err, "Failed to create or update configmap resource for AlertPattern")
				}
			}

			// Get exist bmcForwarderDaemonSet
			log.Info("Getting bmcForwarderDaemonSet")
			bmcForwarderDaemonSet := &v1.DaemonSet{}
			err = r.Get(ctx, client.ObjectKey{
				Namespace: r.BasicConfig.OperatorNamespace,
				Name:      r.BasicConfig.BmcForwarderName,
			}, bmcForwarderDaemonSet)
			if err == nil && len(bmcForwarderDaemonSet.UID) > 0 {
				// If bmcForwarderDaemonSet exist
				restart := false
				if bmcForwarderDaemonSet.Spec.Template.ObjectMeta.Annotations != nil && len(bmcForwarderDaemonSet.Spec.Template.ObjectMeta.Annotations[r.BasicConst.RestartTimestampAnnotation]) > 0 {
					// If bmcForwarderDaemonSet restartTimestamp annotation exist
					restartTimestamp, _ := strconv.ParseInt(bmcForwarderDaemonSet.Spec.Template.ObjectMeta.Annotations[r.BasicConst.RestartTimestampAnnotation], 10, 64)
					log.Info("Checking bmcForwarderDaemonSet need to restart or not", "currentTimestamp", currentTimestamp, "restartTimestamp", restartTimestamp, "existBmcForwarderMicroserviceConfigModified", existBmcForwarderMicroserviceConfigModified)
					if (currentTimestamp-restartTimestamp) > int64(r.BasicConfig.MinRestartInterval)*60 && restartTimestamp < existBmcForwarderMicroserviceConfigModified {
						// If interval greater than minRestartInterval and restartTimestamp less than existBmcForwarderMicroserviceConfigModified mark restart to true
						log.Info("Mark bmcForwarderDaemonSet restart to true due to interval greater than minRestartInterval and restartTimestamp less than existBmcForwarderMicroserviceConfigModified")
						restart = true
					}
				} else {
					// If bmcForwarderDaemonSet restartTimestamp annotation not exist mark restart to true
					log.Info("Mark bmcForwarderDaemonSet restart to true due to missing restartTimestamp annotation")
					restart = true
				}
				if restart {
					// Patching restartTimestamp annotation of bmcForwarderDaemonSet to restart
					log.Info("Patching restartTimestamp annotation of bmcForwarderDaemonSet to restart")
					patch := []byte(fmt.Sprintf(`{"spec":{"template":{"metadata":{"annotations":{"%s": "%d"}}}}}`, r.BasicConst.RestartTimestampAnnotation, currentTimestamp))
					if err = r.Patch(ctx, bmcForwarderDaemonSet, client.RawPatch(types.StrategicMergePatchType, patch)); err != nil {
						log.Error(err, "Failed to patch bmcForwarderDaemonSet")
					}
				}
			} else {
				// If bmcForwarderDaemonSet not exist
				log.Error(err, "Unable to get bmcForwarderDaemonSet")
			}
		}
	}()

	return ctrl.NewControllerManagedBy(mgr).
		For(&loggingv1alpha1.Logging{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.AlertPattern{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Parser{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Throttle{}}, &handler.EnqueueRequestForObject{}).
		Complete(r)
}
