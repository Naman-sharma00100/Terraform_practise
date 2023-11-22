package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	batchv1 "k8s.io/api/batch/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

const (
	serviceAccountName   = "go-server-service-account"
	roleName             = "go-server-role"
	roleBindingName      = "go-server-role-binding"
	kubeConfigPath       = "~/.kube/config"
	defaultListenAddress = ":8080"
)

type jobParams struct {
	Name    string   `json:"name"`
	Image   string   `json:"image"`
	Command []string `json:"command"`
	JobName string   `json:"jobname"`
}

func handleJobRequest(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/job":
		handleJobOperation(w, r, createJob)
	case "/deletejob":
		handleJobOperation(w, r, deleteJob)
	default:
		log.Printf("Redirected to default route, Routing issue.")
		http.Error(w, "Not Found", http.StatusNotFound)
	}
}

func createJob(clientset *kubernetes.Clientset, params jobParams) error {
	var backOffLimit int32 = 0
	job := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name: params.JobName,
		},
		Spec: batchv1.JobSpec{
			Template: v1.PodTemplateSpec{
				Spec: v1.PodSpec{
					Containers: []v1.Container{
						{
							Name:    params.Name,
							Image:   params.Image,
							Command: params.Command,
						},
					},
					RestartPolicy: "Never",
				},
			},
			BackoffLimit: &backOffLimit,
		},
	}

	_, err := clientset.BatchV1().Jobs("default").Create(context.TODO(), job, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("failed to create kubernetes job: %v", err)
	}
	log.Println("Created K8s job successfully")
	return nil
}

func deleteJob(clientset *kubernetes.Clientset, params jobParams) error {
	log.Printf("Attempting to delete job: %s", params.JobName)

	deleteBackground := metav1.DeletePropagationBackground
	err := clientset.BatchV1().Jobs("default").Delete(context.TODO(), params.JobName, metav1.DeleteOptions{
		PropagationPolicy: &deleteBackground,
	})
	if err != nil {
		log.Printf("Failed to delete Kubernetes job '%s': %v", params.JobName, err)
		return fmt.Errorf("failed to delete Kubernetes job: %v", err)
	}

	log.Printf("Deleted K8s job '%s' successfully", params.JobName)
	return nil
}

func handleJobOperation(w http.ResponseWriter, r *http.Request, operation func(*kubernetes.Clientset, jobParams) error) {
	if r.Method != http.MethodPost && r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var params jobParams
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error reading request body: %v", err), http.StatusBadRequest)
		return
	}

	err = json.Unmarshal(body, &params)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error decoding JSON: %v", err), http.StatusBadRequest)
		return
	}

	config, err := rest.InClusterConfig()
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to create kubernetes config: %v", err), http.StatusInternalServerError)
		return
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error creating kubernetes client: %v", err), http.StatusInternalServerError)
		return
	}

	if err := operation(clientset, params); err != nil {
		http.Error(w, fmt.Sprintf("Error performing Kubernetes operation: %v", err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)

}

func main() {
	listenAddress := flag.String("Listen-address", defaultListenAddress, "The address to listen on for HTTP requests")
	flag.Parse()

	http.HandleFunc("/job", handleJobRequest)
	http.HandleFunc("/deletejob", handleJobRequest)

	fmt.Printf("Server listening on %s\n", *listenAddress)
	err := http.ListenAndServe(*listenAddress, nil)
	if err != nil {
		fmt.Printf("Error starting server: %v\n", err)
		os.Exit(1)
	}
}
