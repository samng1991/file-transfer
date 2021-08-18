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

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	//metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	//"k8s.io/apimachinery/pkg/api/errors"
	//"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/runtime"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/source"

	//"reflect"
	"context"
	"crypto/md5"
	"fmt"
	"time"

	loggingv1alpha1 "hkjc.org.hk/mesh/logging-operator/api/v1alpha1"
	operator "hkjc.org.hk/mesh/logging-operator/pkg/operator"
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
	log := ctrllog.FromContext(ctx)

	// TODO: Get resource by req
	// TODO: Create/update configmap by req
	// TODO: if yes then restart daemonset/sts
	log.Info("Getting request AlertPattern")
	alertPattern := &loggingv1alpha1.AlertPattern{}
	err := r.Get(ctx, req.NamespacedName, alertPattern)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
			// Return and don't requeue
			log.Info("AlertPattern resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		// Error reading the object - requeue the request.
		log.Error(err, "Failed to get AlertPattern")
		return ctrl.Result{}, err
	}

	log.Info("Loading AlertPattern")
	alertPatternCfg, err := alertPattern.Load()
	if err != nil {
		log.Info("Failed to load AlertPattern")
		return ctrl.Result{}, err
	}

	// Create or update the corresponding Secret
	log.Info("Create configmap var for AlertPattern in namespace", "OperatorNamespace", r.BasicConfig.OperatorNamespace)
	alertPatternConfigMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      alertPattern.Name,
			Namespace: r.BasicConfig.OperatorNamespace,
			Annotations: {
				"hkjc.org.hk/checksum": md5.Sum([]byte(alertPatternCfg)),
			},
		},
		Data: map[string]string{
			"alert-pattern.conf": alertPatternCfg,
		},
	}

	log.Info("Create or update configmap resource for AlertPattern")
	if _, err := controllerutil.CreateOrUpdate(ctx, r.Client, alertPatternConfigMap, func() error {
		alertPatternConfigMap.ObjectMeta.Annotations["hkjc.org.hk/checksum"] = md5.Sum([]byte(alertPatternCfg))
		alertPatternConfigMap.Data = map[string]string{
			"alert-pattern.conf": alertPatternCfg,
		}
		//alertPatternConfigMap.SetOwnerReferences(nil)
		return nil
	}); err != nil {
		log.Error(err, "Failed to create or update configmap resource for AlertPattern")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *LoggingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	ticker := time.NewTicker(time.Duration(r.BasicConfig.WatchInterval) * time.Second)
	go func() {
		for range ticker.C {
			// TODO: if logging resource got change, then get daemonset/sts restart time and check is it greater than restartedAt annotation.
			// TODO: if :yes then restart daemonset/sts
			/*
				spec.template.metadata.annotations.["kubectl.kubernetes.io/restartedAt"]: "2021-08-16T17:25:56+08:00"
			*/
			fmt.Println("Hello !!")
		}
	}()

	return ctrl.NewControllerManagedBy(mgr).
		For(&loggingv1alpha1.Logging{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.AlertPattern{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Parser{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Throttle{}}, &handler.EnqueueRequestForObject{}).
		Complete(r)
}
