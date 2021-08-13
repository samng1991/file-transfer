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

	//metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	//"k8s.io/apimachinery/pkg/api/errors"
	//"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/runtime"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/source"
	"sigs.k8s.io/controller-runtime/pkg/client"
	//ctrllog "sigs.k8s.io/controller-runtime/pkg/log"

	"context"
	//"reflect"
	//"time"
	"fmt"

	loggingv1alpha1 "hkjc.org.com/mesh/logging-operator/api/v1alpha1"
)

// LoggingReconciler reconciles a Logging object
type LoggingReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=loggings,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=loggings/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=loggings/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=alertpatterns,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=alertpatterns/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=alertpatterns/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=parsers,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=parsers/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=parsers/finalizers,verbs=update
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=throttles,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=throttles/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=logging.mesh.hkjc.org.com,resources=throttles/finalizers,verbs=update

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

	// your logic here
	var inputs loggingv1alpha1.AlertPatternList
	//selector, err := metav1.LabelSelectorAsSelector(&req.Spec.InputSelector)
	//if err != nil {
	//	fmt.Println("Got error1")
	//	return ctrl.Result{}, err
	//}
	fmt.Println(selector)
	if err = r.List(ctx, &inputs, client.InNamespace(req.Namespace)); err != nil {
		fmt.Println("Got error2")
		return ctrl.Result{}, err
	}
	fmt.Println(inputs)

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *LoggingReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&loggingv1alpha1.Logging{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.AlertPattern{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Parser{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Throttle{}}, &handler.EnqueueRequestForObject{}).
		Complete(r)
}
