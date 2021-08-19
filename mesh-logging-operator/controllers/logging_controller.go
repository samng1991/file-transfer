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
	//log := ctrllog.FromContext(ctx)
	//
	//// TODO: Get resource by req
	//// TODO: Create/update configmap by req
	//// TODO: if yes then restart daemonset/sts
	//log.Info("Getting request AlertPattern")
	//alertPattern := &loggingv1alpha1.AlertPattern{}
	//err := r.Get(ctx, req.NamespacedName, alertPattern)
	//if err != nil {
	//	if errors.IsNotFound(err) {
	//		// Request object not found, could have been deleted after reconcile request.
	//		// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
	//		// Return and don't requeue
	//		log.Info("AlertPattern resource not found. Ignoring since object must be deleted")
	//		return ctrl.Result{}, nil
	//	}
	//	// Error reading the object - requeue the request.
	//	log.Error(err, "Failed to get AlertPattern")
	//	return ctrl.Result{}, err
	//}
	//
	//log.Info("Loading AlertPattern")
	//alertPatternCfg, err := alertPattern.Load()
	//if err != nil {
	//	log.Info("Failed to load AlertPattern")
	//	return ctrl.Result{}, err
	//}
	//alertPatternCfgHash := hex.EncodeToString(md5.Sum([]byte(alertPatternCfg))[:])
	//
	//// Create or update the corresponding Secret
	//log.Info("Create configmap var for AlertPattern in namespace", "OperatorNamespace", r.BasicConfig.OperatorNamespace)
	//alertPatternConfigMap := &corev1.ConfigMap{
	//	ObjectMeta: metav1.ObjectMeta{
	//		Name:      alertPattern.Name,
	//		Namespace: r.BasicConfig.OperatorNamespace,
	//		Annotations: map[string]string{
	//			"hkjc.org.hk/checksum": alertPatternCfgHash,
	//		},
	//	},
	//	Data: map[string]string{
	//		"alert-pattern.conf": alertPatternCfg,
	//	},
	//}
	//
	//log.Info("Create or update configmap resource for AlertPattern")
	//if _, err := controllerutil.CreateOrUpdate(ctx, r.Client, alertPatternConfigMap, func() error {
	//	if alertPatternConfigMap.ObjectMeta.Annotations == nil {
	//		alertPatternConfigMap.ObjectMeta.Annotations = map[string]string{}
	//	}
	//	alertPatternConfigMap.ObjectMeta.Annotations["hkjc.org.hk/checksum"] = alertPatternCfgHash
	//	alertPatternConfigMap.Data = map[string]string{
	//		"alert-pattern.conf": alertPatternCfg,
	//	}
	//	alertPatternConfigMap.SetOwnerReferences(nil)
	//	return nil
	//}); err != nil {
	//	log.Error(err, "Failed to create or update configmap resource for AlertPattern")
	//	return ctrl.Result{}, err
	//}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *LoggingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	ctx := context.Background()
	log := ctrllog.FromContext(ctx)
	currentTimestamp := time.Now().Unix()

	ticker := time.NewTicker(time.Duration(r.BasicConfig.WatchInterval) * time.Second)
	go func() {
		for range ticker.C {
			var existBmcForwarderConfigHash string
			var existBmcForwarderConfigModified int64
			existBmcForwarderConfig := &corev1.ConfigMap{}
			_ = r.Get(ctx, client.ObjectKey{
				Namespace: r.BasicConfig.OperatorNamespace,
				Name:      "bmc-forwarder",
			}, existBmcForwarderConfig)
			if len(existBmcForwarderConfig.UID) > 0 {
				if existBmcForwarderConfig.ObjectMeta.Annotations != nil && len(existBmcForwarderConfig.ObjectMeta.Annotations["hkjc.org.hk/checksum"]) > 0 {
					existBmcForwarderConfigHash = existBmcForwarderConfig.ObjectMeta.Annotations["hkjc.org.hk/checksum"]
				}
				if existBmcForwarderConfig.ObjectMeta.Annotations != nil && len(existBmcForwarderConfig.ObjectMeta.Annotations["hkjc.org.hk/modified"]) > 0 {
					existBmcForwarderConfigModified, _ = strconv.ParseInt(existBmcForwarderConfig.ObjectMeta.Annotations["hkjc.org.hk/modified"], 0, 64)
				}
			}

			var bmcForwarderConfig = ""
			var alertPatterns loggingv1alpha1.AlertPatternList
			if err := r.List(ctx, &alertPatterns); err == nil {
				log.Info("Loading AlertPattern")
				alertPatternsConfig, err := alertPatterns.Load()
				if err == nil {
					bmcForwarderConfig = bmcForwarderConfig + alertPatternsConfig
				} else {
					log.Error(err, "Failed to load AlertPattern")
				}
			} else {
				log.Error(err, "Unable to list AlertPattern")
			}
			bmcForwarderConfigMD5 := md5.Sum([]byte(bmcForwarderConfig))
			bmcForwarderConfigHash := hex.EncodeToString(bmcForwarderConfigMD5[:])

			if existBmcForwarderConfigHash != bmcForwarderConfigHash {
				log.Info("Create configmap var for AlertPattern in namespace", "OperatorNamespace", r.BasicConfig.OperatorNamespace)
				existBmcForwarderConfigModified = currentTimestamp
				alertPatternConfigMap := &corev1.ConfigMap{
					ObjectMeta: metav1.ObjectMeta{
						Name:      "bmc-forwarder",
						Namespace: r.BasicConfig.OperatorNamespace,
						Annotations: map[string]string{
							"hkjc.org.hk/checksum": bmcForwarderConfigHash,
							"hkjc.org.hk/modified": strconv.FormatInt(currentTimestamp, 10),
						},
					},
					Data: map[string]string{
						"alert-pattern.conf": bmcForwarderConfig,
					},
				}

				log.Info("Create or update configmap resource for AlertPattern")
				if _, err := controllerutil.CreateOrUpdate(ctx, r.Client, alertPatternConfigMap, func() error {
					if alertPatternConfigMap.ObjectMeta.Annotations == nil {
						alertPatternConfigMap.ObjectMeta.Annotations = map[string]string{}
					}
					alertPatternConfigMap.ObjectMeta.Annotations["hkjc.org.hk/checksum"] = bmcForwarderConfigHash
					alertPatternConfigMap.ObjectMeta.Annotations["hkjc.org.hk/modified"] = strconv.FormatInt(currentTimestamp, 10)
					alertPatternConfigMap.Data = map[string]string{
						"alert-pattern.conf": bmcForwarderConfig,
					}
					alertPatternConfigMap.SetOwnerReferences(nil)
					return nil
				}); err != nil {
					log.Error(err, "Failed to create or update configmap resource for AlertPattern")
				}
			}

			bmcForwarderDaemonSet := &v1.DaemonSet{}
			_ = r.Get(ctx, client.ObjectKey{
				Namespace: r.BasicConfig.OperatorNamespace,
				Name:      r.BasicConfig.BmcForwarderName,
			}, bmcForwarderDaemonSet)
			if len(bmcForwarderDaemonSet.UID )>0 {
				restart := false
				if bmcForwarderDaemonSet.ObjectMeta.Annotations != nil && len(bmcForwarderDaemonSet.ObjectMeta.Annotations["hkjc.org.hk/restartTimestamp"]) > 0 {
					restartTimestamp,_ := strconv.ParseInt(bmcForwarderDaemonSet.ObjectMeta.Annotations["hkjc.org.hk/restartTimestamp"], 10, 64)
					if (currentTimestamp-restartTimestamp) > 60*60 && restartTimestamp < existBmcForwarderConfigModified {
						restart = true
					}
				} else {
					restart = true
				}
				if restart {
					patch := []byte(fmt.Sprintf(`{"metadata":{"annotations":{"hkjc.org.hk/restartTimestamp": "%i"}}}`, currentTimestamp))
					_ = r.Patch(ctx, bmcForwarderDaemonSet, client.RawPatch(types.StrategicMergePatchType, patch))
				}
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
