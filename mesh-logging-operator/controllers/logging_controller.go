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
	"hkjc.org.hk/mesh/logging-operator/pkg/utils"
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

func (r *LoggingReconciler) getExistForwarderMicroserviceConfigInfo(ctx context.Context, configName string) (string, int64) {
	var existForwarderMicroserviceConfigHash string
	var existForwarderMicroserviceConfigModified int64
	existForwarderConfig := &corev1.ConfigMap{}
	err := r.Get(ctx, client.ObjectKey{
		Namespace: r.BasicConfig.OperatorNamespace,
		Name:      configName,
	}, existForwarderConfig)
	if err == nil && len(existForwarderConfig.UID) > 0 {
		if existForwarderConfig.ObjectMeta.Annotations != nil && len(existForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation]) > 0 {
			existForwarderMicroserviceConfigHash = existForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation]
		}
		if existForwarderConfig.ObjectMeta.Annotations != nil && len(existForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation]) > 0 {
			existForwarderMicroserviceConfigModified, _ = strconv.ParseInt(existForwarderConfig.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation], 10, 64)
		}
	}
	return existForwarderMicroserviceConfigHash, existForwarderMicroserviceConfigModified
}

func (r *LoggingReconciler) loadBmcForwarderMicroserviceConfig(ctx context.Context) (map[string]string, string) {
	log := ctrllog.FromContext(ctx)

	var bmcForwarderMicroserviceConfig = ""
	var bmcForwarderMicroserviceConfigMap = map[string]string{}

	var alertPatterns loggingv1alpha1.AlertPatternList
	if err := r.List(ctx, &alertPatterns); err == nil {
		log.Info("Loading alertPatterns")
		alertPatternsConfig, err := alertPatterns.Load()
		if err == nil {
			bmcForwarderMicroserviceConfig += alertPatternsConfig
			bmcForwarderMicroserviceConfigMap["alert-pattern.conf"] = alertPatternsConfig
		} else {
			log.Error(err, "Failed to load alertPatterns")
		}
	} else {
		log.Error(err, "Unable to list alertPatterns")
	}

	bmcForwarderConfigMD5 := md5.Sum([]byte(bmcForwarderMicroserviceConfig))
	bmcForwarderConfigHash := hex.EncodeToString(bmcForwarderConfigMD5[:])
	return bmcForwarderMicroserviceConfigMap, bmcForwarderConfigHash
}

func (r *LoggingReconciler) loadLogstashForwarderMicroserviceConfig(ctx context.Context) (map[string]string, string) {
	log := ctrllog.FromContext(ctx)

	var logstashForwarderMicroserviceConfig = ""
	var logstashForwarderMicroserviceConfigMap = map[string]string{}

	totalCRSize := 0
	var parsers loggingv1alpha1.ParserList
	if err := r.List(ctx, &parsers); err == nil {
		log.Info("Loading parsers")
		totalCRSize += len(parsers.Items)
		parsersConfig, err := parsers.Load()
		if err == nil {
			logstashForwarderMicroserviceConfig += parsersConfig
			logstashForwarderMicroserviceConfigMap["parser.conf"] = parsersConfig
		} else {
			log.Error(err, "Failed to load parsers")
		}
	} else {
		log.Error(err, "Unable to list parsers")
	}

	var throttles loggingv1alpha1.ThrottleList
	if err := r.List(ctx, &throttles); err == nil {
		log.Info("Loading throttles")
		totalCRSize += len(throttles.Items)
		throttlesConfig, err := throttles.Load()
		if err == nil {
			logstashForwarderMicroserviceConfig += throttlesConfig
			logstashForwarderMicroserviceConfigMap["throttles.conf"] = throttlesConfig
		} else {
			log.Error(err, "Failed to load throttles")
		}
	} else {
		log.Error(err, "Unable to list throttles")
	}

	objectMetaSpecs := make([]utils.ObjectMetaSpec, totalCRSize)
	if parsers.Items != nil {
		for i, parser := range parsers.Items {
			objectMetaSpecs[i] = utils.ObjectMetaSpec{
				ExObjectMeta: parser.ObjectMeta,
				Pod:          parser.Spec.Pod,
				Container:    parser.Spec.Container,
			}
		}
	}
	if throttles.Items != nil {
		for i, throttle := range throttles.Items {
			objectMetaSpecs[len(parsers.Items)+i] = utils.ObjectMetaSpec{
				ExObjectMeta: throttle.ObjectMeta,
				Pod:          throttle.Spec.Pod,
				Container:    throttle.Spec.Container,
			}
		}
	}

	rewriteTagsConfig := utils.GetRewriteTagsConfigByExObjectMetas(objectMetaSpecs)
	logstashForwarderMicroserviceConfig += rewriteTagsConfig
	logstashForwarderMicroserviceConfigMap["rewrite-tags.conf"] = rewriteTagsConfig

	logstashForwarderConfigMD5 := md5.Sum([]byte(logstashForwarderMicroserviceConfig))
	logstashForwarderConfigHash := hex.EncodeToString(logstashForwarderConfigMD5[:])
	return logstashForwarderMicroserviceConfigMap, logstashForwarderConfigHash
}

func (r *LoggingReconciler) createOrUpdateForwarderMicroserviceConfigInfo(ctx context.Context, currentTimestamp int64,
	forwarderMicroserviceConfigName string, forwarderConfigHash string, forwarderMicroserviceConfigMap map[string]string) {
	log := ctrllog.FromContext(ctx)
	// Create a new ConfigMap for current forwarderMicroserviceConfig
	log.Info("Create configmap var for AlertPattern in namespace", "forwarderMicroserviceConfigName", forwarderMicroserviceConfigName, "OperatorNamespace", r.BasicConfig.OperatorNamespace)
	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      forwarderMicroserviceConfigName,
			Namespace: r.BasicConfig.OperatorNamespace,
			Annotations: map[string]string{
				r.BasicConst.ChecksumAnnotation: forwarderConfigHash,
				r.BasicConst.ModifiedAnnotation: strconv.FormatInt(currentTimestamp, 10),
			},
		},
		Data: forwarderMicroserviceConfigMap,
	}

	// Create or update current forwarderMicroserviceConfig to k8s
	log.Info("Create or update configmap resource for AlertPattern", "forwarderMicroserviceConfigName", forwarderMicroserviceConfigName)
	if _, err := controllerutil.CreateOrUpdate(ctx, r.Client, configMap, func() error {
		if configMap.ObjectMeta.Annotations == nil {
			configMap.ObjectMeta.Annotations = map[string]string{}
		}
		configMap.ObjectMeta.Annotations[r.BasicConst.ChecksumAnnotation] = forwarderConfigHash
		configMap.ObjectMeta.Annotations[r.BasicConst.ModifiedAnnotation] = strconv.FormatInt(currentTimestamp, 10)
		configMap.Data = forwarderMicroserviceConfigMap
		configMap.SetOwnerReferences(nil)
		return nil
	}); err != nil {
		log.Error(err, "Failed to create or update configmap resource for AlertPattern", "forwarderMicroserviceConfigName", forwarderMicroserviceConfigName)
	}
}

func (r *LoggingReconciler) restartForwarderDaemonSet(ctx context.Context, forwarderName string, currentTimestamp int64, existForwarderMicroserviceConfigModified int64) {
	log := ctrllog.FromContext(ctx)
	log.Info("Getting bmcForwarderDaemonSet", "forwarderName", forwarderName)

	forwarderDaemonSet := &v1.DaemonSet{}
	err := r.Get(ctx, client.ObjectKey{
		Namespace: r.BasicConfig.OperatorNamespace,
		Name:      forwarderName,
	}, forwarderDaemonSet)
	if err == nil && len(forwarderDaemonSet.UID) > 0 {
		// If forwarderDaemonSet exist
		restart := false
		if forwarderDaemonSet.Spec.Template.ObjectMeta.Annotations != nil && len(forwarderDaemonSet.Spec.Template.ObjectMeta.Annotations[r.BasicConst.RestartTimestampAnnotation]) > 0 {
			// If forwarderDaemonSet restartTimestamp annotation exist
			restartTimestamp, _ := strconv.ParseInt(forwarderDaemonSet.Spec.Template.ObjectMeta.Annotations[r.BasicConst.RestartTimestampAnnotation], 10, 64)
			log.Info("Checking forwarderDaemonSet need to restart or not", "forwarderName", forwarderName, "currentTimestamp", currentTimestamp, "restartTimestamp", restartTimestamp, "existForwarderMicroserviceConfigModified", existForwarderMicroserviceConfigModified)
			if (currentTimestamp-restartTimestamp) > int64(r.BasicConfig.MinRestartInterval)*60 && restartTimestamp < existForwarderMicroserviceConfigModified {
				// If interval greater than minRestartInterval and restartTimestamp less than existForwarderMicroserviceConfigModified mark restart to true
				log.Info("Mark forwarderDaemonSet restart to true due to interval greater than minRestartInterval and restartTimestamp less than existForwarderMicroserviceConfigModified", "forwarderName", forwarderName)
				restart = true
			}
		} else {
			// If forwarderDaemonSet restartTimestamp annotation not exist mark restart to true
			log.Info("Mark forwarderDaemonSet restart to true due to missing restartTimestamp annotation", "forwarderName", forwarderName)
			restart = true
		}
		if restart {
			// Patching restartTimestamp annotation of forwarderDaemonSet to restart
			log.Info("Patching restartTimestamp annotation of forwarderDaemonSet to restart", "forwarderName", forwarderName)
			patch := []byte(fmt.Sprintf(`{"spec":{"template":{"metadata":{"annotations":{"%s": "%d"}}}}}`, r.BasicConst.RestartTimestampAnnotation, currentTimestamp))
			if err = r.Patch(ctx, forwarderDaemonSet, client.RawPatch(types.StrategicMergePatchType, patch)); err != nil {
				log.Error(err, "Failed to patch forwarderDaemonSet", "forwarderName", forwarderName)
			}
		}
	} else {
		// If forwarderDaemonSet not exist
		log.Error(err, "Unable to get forwarderDaemonSet", "forwarderName", forwarderName)
	}
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

			// Get exist forwarder microservice config and its info
			existBmcForwarderMicroserviceConfigHash, existBmcForwarderMicroserviceConfigModified := r.getExistForwarderMicroserviceConfigInfo(ctx, r.BasicConst.BmcForwarderMicroserviceConfig)
			existLogstashForwarderMicroserviceConfigHash, existLogstashForwarderMicroserviceConfigModified := r.getExistForwarderMicroserviceConfigInfo(ctx, r.BasicConst.LogstashForwarderMicroserviceConfig)

			// Load current forwarder microservice config and its info
			bmcForwarderMicroserviceConfigMap, bmcForwarderConfigHash := r.loadBmcForwarderMicroserviceConfig(ctx)
			logstashForwarderMicroserviceConfigMap, logstashForwarderConfigHash := r.loadLogstashForwarderMicroserviceConfig(ctx)

			// Check current and exist bmcForwarderMicroserviceConfig checksum
			log.Info("Comparing hash", "existBmcForwarderMicroserviceConfigHash", existBmcForwarderMicroserviceConfigHash, "bmcForwarderConfigHash", bmcForwarderConfigHash)
			if existBmcForwarderMicroserviceConfigHash != bmcForwarderConfigHash {
				// If current and exist bmcForwarderMicroserviceConfig checksum not same
				existBmcForwarderMicroserviceConfigModified = currentTimestamp
				r.createOrUpdateForwarderMicroserviceConfigInfo(ctx, currentTimestamp,
					r.BasicConst.BmcForwarderMicroserviceConfig, bmcForwarderConfigHash, bmcForwarderMicroserviceConfigMap)
			}

			// Check current and exist logstashForwarderMicroserviceConfig checksum
			log.Info("Comparing hash", "existLogstashForwarderMicroserviceConfigHash", existLogstashForwarderMicroserviceConfigHash, "logstashForwarderConfigHash", logstashForwarderConfigHash)
			if existLogstashForwarderMicroserviceConfigHash != logstashForwarderConfigHash {
				// If current and exist logstashForwarderConfigHash checksum not same
				existLogstashForwarderMicroserviceConfigModified = currentTimestamp
				r.createOrUpdateForwarderMicroserviceConfigInfo(ctx, currentTimestamp,
					r.BasicConst.LogstashForwarderMicroserviceConfig, logstashForwarderConfigHash, logstashForwarderMicroserviceConfigMap)
			}

			r.restartForwarderDaemonSet(ctx, r.BasicConfig.BmcForwarderName, currentTimestamp, existBmcForwarderMicroserviceConfigModified)
			r.restartForwarderDaemonSet(ctx, r.BasicConfig.LogstashForwarderName, currentTimestamp, existLogstashForwarderMicroserviceConfigModified)
		}
	}()

	return ctrl.NewControllerManagedBy(mgr).
		For(&loggingv1alpha1.Logging{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.AlertPattern{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Parser{}}, &handler.EnqueueRequestForObject{}).
		Watches(&source.Kind{Type: &loggingv1alpha1.Throttle{}}, &handler.EnqueueRequestForObject{}).
		Complete(r)
}
