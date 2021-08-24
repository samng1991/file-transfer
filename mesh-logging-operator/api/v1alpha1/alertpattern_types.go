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

package v1alpha1

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sort"
)

type AlertPatternItem struct {
	//+kubebuilder:validation:Required
	EventId string `json:"eventId,omitempty"`
	//+kubebuilder:validation:Required
	Regex string `json:"regex,omitempty"`
}

// AlertPatternSpec defines the desired state of AlertPattern
type AlertPatternSpec struct {
	//+kubebuilder:validation:Required
	Pod       string `json:"pod,omitempty"`
	Container string `json:"container,omitempty"`
	//+kubebuilder:validation:Required
	AlertPatternItems []AlertPatternItem `json:"alertPatterns,omitempty"`
}

// AlertPatternStatus defines the observed state of AlertPattern
type AlertPatternStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// AlertPattern is the Schema for the alertpatterns API
type AlertPattern struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   AlertPatternSpec   `json:"spec,omitempty"`
	Status AlertPatternStatus `json:"status,omitempty"`
}

func (alertPattern AlertPattern) Load() (string, error) {
	log := ctrllog.FromContext(context.Background())

	var buf bytes.Buffer
	merge := func(elem AlertPatternItem) error {
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(alertPattern.Namespace + "_" + alertPattern.ObjectMeta.Name))

		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		var pod = alertPattern.Spec.Pod + "-*"
		var container = alertPattern.Spec.Container
		if len(container) == 0 {
			container = "*"
		}

		//buf.WriteString("[Filter]\n")
		//buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		//buf.WriteString(fmt.Sprintf("    Match   container.var.log.containers.%s_%s_%s-*.log\n", pod, alertPattern.Namespace, container))
		//buf.WriteString(fmt.Sprintf("    Rule    $stream .* %s.$TAG false\n", encodedNamespacedName))

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		buf.WriteString(fmt.Sprintf("    Match   container.var.log.containers.%s_%s_%s-*.log\n", pod, alertPattern.Namespace, container))
		buf.WriteString(fmt.Sprintf("    Rule    $message %s bmc.%s.$TAG false\n", elem.Regex, encodedNamespacedName))

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    record_modifier\n"))
		buf.WriteString(fmt.Sprintf("    Match   bmc.%s.*\n", encodedNamespacedName))
		buf.WriteString(fmt.Sprintf("    Record  eventID %s\n", elem.EventId))

		return nil
	}

	for _, elem := range alertPattern.Spec.AlertPatternItems {
		log.Info("Merging AlertPatternItem", "Namespace", alertPattern.Namespace, "Name", alertPattern.ObjectMeta.Name, "EventId", elem.EventId, "Regex", elem.Regex)
		if err := merge(elem); err != nil {
			return "", err
		}
	}

	return buf.String(), nil
}

//+kubebuilder:object:root=true

// AlertPatternList contains a list of AlertPattern
type AlertPatternList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []AlertPattern `json:"items"`
}

func (alertPatterns AlertPatternList) Load() (string, error) {
	log := ctrllog.FromContext(context.Background())

	namespacedName := func(namespace string, name string) string {
		return namespace + "_" + name
	}

	alertPatternItems := alertPatterns.Items
	sort.SliceStable(alertPatternItems, func(i, j int) bool {
		return namespacedName(alertPatternItems[i].Namespace, alertPatternItems[i].ObjectMeta.Name) <
			namespacedName(alertPatternItems[j].Namespace, alertPatternItems[j].ObjectMeta.Name)
	})

	var alertPatternsConfig = ""
	for _, alertPatternItem := range alertPatterns.Items {
		alertPatternConfig, err := alertPatternItem.Load()
		if err == nil {
			alertPatternsConfig = alertPatternsConfig + alertPatternConfig
		} else {
			log.Error(err, "Unable to load AlertPattern")
		}
	}

	return alertPatternsConfig, nil
}

func init() {
	SchemeBuilder.Register(&AlertPattern{}, &AlertPatternList{})
}
