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

func (parser Parser) Load() (string, string, error) {
	log := ctrllog.FromContext(context.Background())

	var parsersConfigBuf bytes.Buffer
	var parserFiltersConfigBuf bytes.Buffer
	mergeSingleLineParser := func(singleLineParser SingleLineParser) error {
		namespacedName := utils.ExObjectMeta(parser.ObjectMeta).GetNamespacedName()
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespacedName))

		if len(parser.Spec.Pod) == 0 || len(parser.Spec.Container) == 0 {
			log.Info("Skip loading SingleLineParser due to empty pod or container name", "namespacedName", namespacedName)
		} else if len(singleLineParser.Regex) == 0 {
			log.Info("Skip loading SingleLineParser due to empty Regex", "namespacedName", namespacedName)
		} else {
			// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
			var pod = parser.Spec.Pod + "-*"
			var container = parser.Spec.Container

			parsersConfigBuf.WriteString("[PARSER]\n")
			parsersConfigBuf.WriteString(fmt.Sprintf("    Name     %s\n", encodedNamespacedName))
			parsersConfigBuf.WriteString(fmt.Sprintf("    Format   regex\n"))
			parsersConfigBuf.WriteString(fmt.Sprintf("    Regex    %s\n", singleLineParser.Regex))

			parserFiltersConfigBuf.WriteString("[Filter]\n")
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Name         parser\n"))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Match        %s.container.var.log.containers.%s_%s_%s-*.log\n", encodedNamespacedName, pod, parser.Namespace, container))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Key_Name     message\n"))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Parser       %s\n", encodedNamespacedName))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Preserve_Key On\n"))
		}

		return nil
	}
	mergeMultilineParser := func(multilineParser MultilineParser) error {
		namespacedName := utils.ExObjectMeta(parser.ObjectMeta).GetNamespacedName()
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespacedName))

		if len(parser.Spec.Pod) == 0 || len(parser.Spec.Container) == 0 {
			log.Info("Skip loading MultilineParser due to empty pod or container name", "namespacedName", namespacedName)
		} else if multilineParser.FlushTimeout == 0 || len(multilineParser.StartStateRegex) == 0 || len(multilineParser.ContRegex) == 0 {
			log.Info("Skip loading MultilineParser due to empty FlushTimeout or StartStateRegex or ContRegex", "namespacedName", namespacedName)
		} else {
			// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
			var pod = parser.Spec.Pod + "-*"
			var container = parser.Spec.Container

			parsersConfigBuf.WriteString("[MULTILINE_PARSER]\n")
			parsersConfigBuf.WriteString(fmt.Sprintf("    Name          %s\n", encodedNamespacedName))
			parsersConfigBuf.WriteString(fmt.Sprintf("    Type          regex"))
			parsersConfigBuf.WriteString(fmt.Sprintf("    flush_timeout %d\n", multilineParser.FlushTimeout))
			parsersConfigBuf.WriteString(fmt.Sprintf("    rule      \"start_state\"    %s\n", multilineParser.StartStateRegex))
			parsersConfigBuf.WriteString(fmt.Sprintf("    rule      \"cont\"           %s\n", multilineParser.ContRegex))

			parserFiltersConfigBuf.WriteString("[Filter]\n")
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Name                  multiline\n"))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    Match                 %s.container.var.log.containers.%s_%s_%s-*.log\n", encodedNamespacedName, pod, parser.Namespace, container))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    multiline.key_content message\n"))
			parserFiltersConfigBuf.WriteString(fmt.Sprintf("    multiline.parser      %s\n", multilineParser.Parser))
		}

		return nil
	}

	log.Info("Merging SingleLineParser", "Namespace", parser.Namespace, "Name", parser.ObjectMeta.Name, "Regex", parser.Spec.SingleLineParser.Regex)
	if err := mergeSingleLineParser(parser.Spec.SingleLineParser); err != nil {
		return "", "", err
	}
	if err := mergeMultilineParser(parser.Spec.MultilineParser); err != nil {
		return "", "", err
	}

	return parsersConfigBuf.String(), parserFiltersConfigBuf.String(), nil
}

//+kubebuilder:object:root=true

// ParserList contains a list of Parser
type ParserList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Parser `json:"items"`
}

func (parserList ParserList) Load() (string, string, error) {
	log := ctrllog.FromContext(context.Background())

	parsers := parserList.Items
	sort.SliceStable(parsers, func(i, j int) bool {
		return utils.ExObjectMeta(parsers[i].ObjectMeta).GetNamespacedName() <
			utils.ExObjectMeta(parsers[j].ObjectMeta).GetNamespacedName()
	})

	var parsersConfig = ""
	var parserFiltersConfig = ""
	for _, parser := range parsers {
		parserConfig, parserFilterConfig, err := parser.Load()
		if err == nil {
			parsersConfig += parsersConfig + parserConfig
			parserFiltersConfig += parserFilterConfig
		} else {
			log.Error(err, "Unable to load parser config", "namespacedName", utils.ExObjectMeta(parser.ObjectMeta).GetNamespacedName())
		}
	}

	return parsersConfig, parserFiltersConfig, nil
}

func init() {
	SchemeBuilder.Register(&Parser{}, &ParserList{})
}
