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
	"hkjc.org.hk/mesh/logging-operator/pkg/utils"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
	"sort"
)

type SingleLineParser struct {
	//+kubebuilder:validation:Required
	Regex string `json:"regex,omitempty"`
}

type MultilineParser struct {
	FlushTimeout int `json:"flushTimeout,omitempty"`
	//+kubebuilder:validation:Required
	Parser          string `json:"parser,omitempty"`
	StartStateRegex string `json:"startStateRegex,omitempty"`
	ContRegex       string `json:"contRegex,omitempty"`
}

// ParserSpec defines the desired state of Parser
type ParserSpec struct {
	//+kubebuilder:validation:Required
	Pod              string           `json:"pod,omitempty"`
	Container        string           `json:"container,omitempty"`
	SingleLineParser SingleLineParser `json:"singleLineParser,omitempty"`
	MultilineParser  MultilineParser  `json:"multilineParser,omitempty"`
}

// ParserStatus defines the observed state of Parser
type ParserStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// Parser is the Schema for the parsers API
type Parser struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ParserSpec   `json:"spec,omitempty"`
	Status ParserStatus `json:"status,omitempty"`
}

func (parser Parser) Load() (string, error) {
	log := ctrllog.FromContext(context.Background())

	var buf bytes.Buffer
	merge := func(namespace string, name string, pod string, container string) error {
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespace + "_" + name))

		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		pod = pod + "-*"
		if len(container) == 0 {
			container = "*"
		}

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		buf.WriteString(fmt.Sprintf("    Match   container.var.log.containers.%s_%s_%s-*.log\n", pod, namespace, container))
		buf.WriteString(fmt.Sprintf("    Rule    $stream .* %s.$TAG false\n", encodedNamespacedName))

		return nil
	}
	mergeSingleLineParser := func(namespace string, name string, pod string, container string, singleLineParser SingleLineParser) error {
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespace + "_" + name))

		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		pod = pod + "-*"
		if len(container) == 0 {
			container = "*"
		}

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name     parser\n"))
		buf.WriteString(fmt.Sprintf("    Match    %s.container.var.log.containers.%s_%s_%s-*.log\n", encodedNamespacedName, pod, namespace, container))
		buf.WriteString(fmt.Sprintf("    Key_Name message\n"))
		buf.WriteString(fmt.Sprintf("    Format regex\n"))
		buf.WriteString(fmt.Sprintf("    Regex  %s\n", singleLineParser.Regex))
		buf.WriteString(fmt.Sprintf("    Reserve_Data On\n"))

		return nil
	}
	mergeMultilineParser := func(namespace string, name string, pod string, container string, multilineParser MultilineParser) error {
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespace + "_" + name))

		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		pod = pod + "-*"
		if len(container) == 0 {
			container = "*"
		}

		buf.WriteString("[MULTILINE_PARSER]\n")
		buf.WriteString(fmt.Sprintf("    Name          %s\n", encodedNamespacedName))
		buf.WriteString(fmt.Sprintf("    Type          regex"))
		buf.WriteString(fmt.Sprintf("    flush_timeout %d\n", multilineParser.FlushTimeout))
		buf.WriteString(fmt.Sprintf("    rule      \"start_state\"    %s\n", multilineParser.StartStateRegex))
		buf.WriteString(fmt.Sprintf("    rule      \"cont\"           %s\n", multilineParser.ContRegex))

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name                  multiline\n"))
		buf.WriteString(fmt.Sprintf("    Match                 %s.container.var.log.containers.%s_%s_%s-*.log\n", encodedNamespacedName, pod, namespace, container))
		buf.WriteString(fmt.Sprintf("    multiline.key_content message\n"))
		buf.WriteString(fmt.Sprintf("    multiline.parser      %s\n", multilineParser.Parser))

		return nil
	}

	log.Info("Merging SingleLineParser", "Namespace", parser.Namespace, "Name", parser.ObjectMeta.Name, "Regex", parser.Spec.SingleLineParser.Regex)
	if err := merge(parser.Namespace, parser.ObjectMeta.Name, parser.Spec.Pod, parser.Spec.Container); err != nil {
		return "", err
	}
	if err := mergeSingleLineParser(parser.Namespace, parser.ObjectMeta.Name, parser.Spec.Pod, parser.Spec.Container, parser.Spec.SingleLineParser); err != nil {
		return "", err
	}
	if err := mergeMultilineParser(parser.Namespace, parser.ObjectMeta.Name, parser.Spec.Pod, parser.Spec.Container, parser.Spec.MultilineParser); err != nil {
		return "", err
	}

	return buf.String(), nil
}

//+kubebuilder:object:root=true

// ParserList contains a list of Parser
type ParserList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Parser `json:"items"`
}

func (parserList ParserList) Load() (string, error) {
	log := ctrllog.FromContext(context.Background())

	namespacedName := func(namespace string, name string) string {
		return namespace + "_" + name
	}

	parsers := parserList.Items
	sort.SliceStable(parsers, func(i, j int) bool {
		return utils.ExObjectMeta(parsers[i].ObjectMeta).GetNamespacedName() <
			utils.ExObjectMeta(parsers[j].ObjectMeta).GetNamespacedName()
	})

	var parsersConfig = ""
	for _, parser := range parsers {
		parserConfig, err := parser.Load()
		if err == nil {
			parsersConfig = parsersConfig + parserConfig
		} else {
			log.Error(err, "Unable to load parser config", "namespacedName", utils.ExObjectMeta(parser.ObjectMeta).GetNamespacedName())
		}
	}

	return parsersConfig, nil
}

func init() {
	SchemeBuilder.Register(&Parser{}, &ParserList{})
}
