package utils

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type ExObjectMeta metav1.ObjectMeta

func (objectMeta ExObjectMeta) GetNamespacedName() string {
	return objectMeta.Namespace + "_" + objectMeta.Name
}
