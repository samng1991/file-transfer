package utils

import (
	"bytes"
	"encoding/base64"
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type ExObjectMeta metav1.ObjectMeta

type ObjectMetaSpec struct {
	ExObjectMeta ExObjectMeta
	Pod          string
	Container    string
}

func (objectMeta ExObjectMeta) GetNamespacedName() string {
	return objectMeta.Namespace + "_" + objectMeta.Name
}

func GetRewriteTagsConfigByExObjectMetas(objectMetaSpecs []ObjectMetaSpec) (string, error) {
	var buf bytes.Buffer
	for _, objectMetaSpec := range objectMetaSpecs {
		namespacedName := objectMetaSpec.ExObjectMeta.GetNamespacedName()
		encodedNamespacedName := base64.StdEncoding.EncodeToString([]byte(namespacedName))

		// kube.var.log.containers.apache-logs-annotated_default_apache-aeeccc7a9f00f6e4e066aeff0434cf80621215071f1b20a51e8340aa7c35eac6.log
		var pod = objectMetaSpec.Pod + "-*"
		var container = objectMetaSpec.Container

		buf.WriteString("[Filter]\n")
		buf.WriteString(fmt.Sprintf("    Name    rewrite_tag\n"))
		buf.WriteString(fmt.Sprintf("    Match   container.var.log.containers.%s_%s_%s-*.log\n", pod, objectMetaSpec.ExObjectMeta.Namespace, container))
		buf.WriteString(fmt.Sprintf("    Rule    $stream .* %s.$TAG false\n", encodedNamespacedName))
	}
	return buf.String(), nil
}
