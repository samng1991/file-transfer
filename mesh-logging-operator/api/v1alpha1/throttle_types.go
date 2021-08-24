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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ThrottleSpec defines the desired state of Throttle
type ThrottleSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Foo is an example field of Throttle. Edit throttle_types.go to remove/update
	Foo string `json:"foo,omitempty"`
}

// ThrottleStatus defines the observed state of Throttle
type ThrottleStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// Throttle is the Schema for the throttles API
type Throttle struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ThrottleSpec   `json:"spec,omitempty"`
	Status ThrottleStatus `json:"status,omitempty"`
}

func (throttle Throttle) Load() (string, error) {
	return "", nil
}

//+kubebuilder:object:root=true

// ThrottleList contains a list of Throttle
type ThrottleList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Throttle `json:"items"`
}

func (throttleList ThrottleList) Load() (string, error) {
	return "", nil
}

func init() {
	SchemeBuilder.Register(&Throttle{}, &ThrottleList{})
}
