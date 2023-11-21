package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
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
	jobName              = "dynamic-job"
	serviceAccountName   = "go-server-service-account"
	roleName             = "go-server-role"
	roleBindingName      = "go-server-role-binding"
	kubeConfigPath       = "~/.kube/config"
	defaultListenAddress = ":8080"
)

type jobParams struct {
	Image   string   `json:"image"`
	Command []string `json:"command"`
}

func createJob(clientset *kubernetes.Clientset, params jobParams) error {
	var backOffLimit int32 = 0
	job := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name: jobName,
		},
		Spec: batchv1.JobSpec{
			Template: v1.PodTemplateSpec{
				Spec: v1.PodSpec{
					Containers: []v1.Container{
						{
							Name:    "job-container",
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

func handleJobRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var params jobParams
	body, err := ioutil.ReadAll(r.Body)
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

	err = createJob(clientset, params)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error creating Kubernetes job: %v", err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)

}

func main() {
	listenAddress := flag.String("Listen-address", defaultListenAddress, "The address to listen on for HTTP requests")
	flag.Parse()

	http.HandleFunc("/job", handleJobRequest)

	fmt.Printf("Server listening on %s\n", *listenAddress)
	err := http.ListenAndServe(*listenAddress, nil)
	if err != nil {
		fmt.Printf("Error starting server: %v\n", err)
		os.Exit(1)
	}
}
