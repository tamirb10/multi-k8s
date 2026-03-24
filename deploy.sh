docker build -t tamirb915/multi-client:latest -t tamirb915/multi-client:$SHA -f ./client/Dockerfile ./client
docker build -t tamirb915/multi-server:latest -t tamirb915/multi-server:$SHA -f ./server/Dockerfile ./server
docker build -t tamirb915/multi-worker:latest -t tamirb915/multi-worker:$SHA -f ./worker/Dockerfile ./worker
docker push tamirb915/multi-client:latest
docker push tamirb915/multi-server:latest
docker push tamirb915/multi-worker:latest
docker push tamirb915/multi-client:$SHA
docker push tamirb915/multi-server:$SHA
docker push tamirb915/multi-worker:$SHA
kubectl apply -f k8s

kubectl set image deployments/server-deployment server=tamirb915/multi-server:$SHA
kubectl set image deployments/client-deployment client=tamirb915/multi-client:$SHA
kubectl set image deployments/worker-deployment worker=tamirb915/multi-worker:$SHA