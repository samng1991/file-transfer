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

package main

import (
	"flag"
	"io/ioutil"
	"os"

	// Import all Kubernetes client auth plugins (e.g. Azure, GCP, OIDC, etc.)
	// to ensure that exec-entrypoint and run can make use of them.
	_ "k8s.io/client-go/plugin/pkg/client/auth"

	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	loggingv1alpha1 "hkjc.org.hk/mesh/logging-operator/api/v1alpha1"
	"hkjc.org.hk/mesh/logging-operator/controllers"
	operator "hkjc.org.hk/mesh/logging-operator/pkg/operator"
	//+kubebuilder:scaffold:imports
)

var (
	scheme   = runtime.NewScheme()
	setupLog = ctrl.Log.WithName("setup")
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))

	utilruntime.Must(loggingv1alpha1.AddToScheme(scheme))
	//+kubebuilder:scaffold:scheme
}

func main() {
	var metricsAddr string
	var enableLeaderElection bool
	var probeAddr string
	var bmcForwarderName string
	var watchInterval int
	var minRestartInterval int
	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false,
		"Enable leader election for controller manager. "+
			"Enabling this will ensure there is only one active controller manager.")
	flag.StringVar(&bmcForwarderName, "bmc-forwarder-name", "fluentd-fluent-bit", "BMC forwarder daemonset name.")
	flag.IntVar(&watchInterval, "watch-interval", 60, "The interval in second that operator to watch config change.")
	flag.IntVar(&minRestartInterval, "min-restart-interval", 60, "The min interval in minute that operator would restart forwarder/aggregator for updating config.")
	opts := zap.Options{
		Development: true,
	}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()

	operatorNamespace := "default"
	if operatorNamespaceByte, err := ioutil.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace"); err != nil {
		setupLog.Error(err, "unable to getting namespace from /var/run/secrets/kubernetes.io/serviceaccount/namespace")
		os.Exit(1)
	} else {
		operatorNamespace = string(operatorNamespaceByte)
	}

	ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		MetricsBindAddress:     metricsAddr,
		Port:                   9443,
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeaderElection,
		LeaderElectionID:       "9c983dc9.mesh.hkjc.org.hk",
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err = (&controllers.LoggingReconciler{
		Client: mgr.GetClient(),
		Scheme: mgr.GetScheme(),
		BasicConfig: operator.BasicConfig{
			WatchInterval:      watchInterval,
			MinRestartInterval: minRestartInterval,
			OperatorNamespace:  operatorNamespace,
			BmcForwarderName:   bmcForwarderName,
		},
		BasicConst: operator.BasicConst{
			ChecksumAnnotation:             "hkjc.org.hk/checksum",
			ModifiedAnnotation:             "hkjc.org.hk/modified",
			RestartTimestampAnnotation:     "hkjc.org.hk/restartTimestamp",
			BmcForwarderMicroserviceConfig: "bmc-forwarder-microservice",
		},
	}).SetupWithManager(mgr); err != nil {
		setupLog.Error(err, "unable to create controller", "controller", "Logging")
		os.Exit(1)
	}
	//+kubebuilder:scaffold:builder

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up health check")
		os.Exit(1)
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	setupLog.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		setupLog.Error(err, "problem running manager")
		os.Exit(1)
	}
}
