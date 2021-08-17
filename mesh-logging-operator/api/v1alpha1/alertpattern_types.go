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
	"encoding/base64"
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type AlertPatternItem struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file
	EventId string `json:"eventId,omitempty"`
	Regex   string `json:"regex,omitempty"`
}

// AlertPatternSpec defines the desired state of AlertPattern
type AlertPatternSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file
	Containers        []string           `json:"containers,omitempty"`
	AlertPatternItems []AlertPatternItem `json:"alertPatterns,omitempty"`
}

// AlertPatternStatus defines the observed state of AlertPattern
type AlertPatternStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
	Effected bool `json:"effected"`
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
	var buf bytes.Buffer

	merge := func(elem AlertPatternItem) error {
		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		encodedName := base64.StdEncoding.EncodeToString([]byte(alertPattern.Name))

		var container = alertPattern.ObjectMeta.Annotations["hkjc.org.hk/container"]
		if len(container) == 0 {
			container = "*"
		}

		//[FILTER]
		//	Name          rewrite_tag
		//	Match         test_tag
		//	Rule          $tool ^(fluent)$  from.$TAG.new.$tool.$sub['s1']['s2'].out false
		//	Emitter_Name  re_emitted
		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		buf.WriteString(fmt.Sprintf("    Match    *.var.log.containers.%s_%s_%s-*.log\n", alertPattern.Name, alertPattern.Namespace, container))
		buf.WriteString(fmt.Sprintf("    Rule    $stream .* %s.$TAG false\n", encodedName))

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		buf.WriteString(fmt.Sprintf("    Match    %s.*.var.log.containers.%s_%s_%s-*.log\n", encodedName, alertPattern.Namespace, alertPattern.Namespace, container))
		buf.WriteString(fmt.Sprintf("    Rule    $log %s bmc.$TAG false\n", elem.Regex))

		return nil
	}

	for _, elem := range alertPattern.Spec.AlertPatternItems {
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

func init() {
	SchemeBuilder.Register(&AlertPattern{}, &AlertPatternList{})
}
