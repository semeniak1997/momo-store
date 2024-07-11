# Momo Store aka Пельменная №2


### Momo-store: [std-025-02-momo-store.ru](https://std-025-02-momo-store.ru)

## Репозиторий
Репозиторий содержит код, который позволяет развернуть в облаке Yandex Cloude проект "momo-store"

```
momo-store
 |- backend        
 |- frontend       
 |- infrastructure
     |- terraform
        |- momo-images
     |- scripts
 |- helm       
     |- backend
     |- frontend
     |- grafana
     |- prometheus
 |- metrics
```

## Описание
1) Директория backend содержит исходный код бэкэнда на языке Go, Dockerfile для контейниризации приложения, файл .gitlab-ci.yml, в котором описаны этапы CI/CD процессов;
2) Директория frontend содержит исходный код фронтенда на языке nodejs, Dockerfile для контейниризации приложения, файл .gitlab-ci.yml, в котором описаны этапы CI/CD процессов;
3) Директория infrastructure/terraform содержит файлы конфигурации для развертывания инфраструктуры в Yandex Cloud. Также содержит директория momo-images, содержащая картинки, которые загружаются в новый бакет Yandex Object Storage;
4) Директория infrastructure/scripts содержит 2 bash-скрипта. Bash-скрипт static_kubeconfig.sh выполняется для генерации статического конфигурационного файла для утилиты kubectl. Bash-скрипт cert_install.sh выполняется для добавления SSL-сертификата в Cert Manager, а также установки Ingress-контроллера Nginx.
5) Директория helm содержит helm чарты для приложения momo-store, grafana, prometheus;
6) Директория metrics содержит скриншоты из браузера с примерами дашбордов с метриками из Grafana. 

## Разворачивание инфраструктуры в облаке Yandexс Cloude с помощью terraform
1) Создать сервисный аккаунт с ролью editor
2) Получить статический ключ доступа (access_key и secret_key)
3) Создать бакет с ограниченным доступом для хранения состояния terraform - state-std-025-02
4) Описать backend "s3" конфигурацию в файле s3.tf
5) Присвоить значения переменным в файле variables.tf
6) provider.tf - конфигурация провайдера
7) main.tf - основная конфигурация. Создание ресурсов в Yandex Cloud (Network, Service account config, k8s Cluster with 2 nodes, Security, Public static IP,  DNS zone with records, Static key for sa, New bucket for momo images, Momo images)
6) Последовательно выполнить команды:
```
cd infrastructure/terraform/
terraform init
terraform plan
terraform apply
```
* Файл .terraformrc находится в корневой папке ВМ
### Object Storage
Проверить, что состояние terraform сохраняется в созданном ранее бакете в Yandex Object Storage.
Проверить, что картинки, находящаяся в директории momo-images, успешно загружены в новый бакет, описанный в main.tf.

### Доменное имя
Зарегистрировать домен для приложения.
Указать адреса серверов имен Yandex Cloud в DNS-записях вашего регистратора:
- ns1.yandexcloud.net
- ns2.yandexcloud.net

<img width="700" alt="image" src="https://storage.yandexcloud.net/std-025-02-images/network.png">


## Автоматический процесс CI/CD
В корневой директории проекта находится файл .gitlab-ci.yml, который отслеживает изменения в директориях backend, frontend, helm/backend и helm.акщтеутв. В случае изменения запускает процесс CI/CD, описанный в файлах /backend/.gitlab-ci.yml и /frontend/.gitlab-ci.yml.
Процесс CI/CD состоит из следующих этапов:
1) build - упаковка приложения в Docker-образ (используется мультистейдж Dockerfile). Полученный образ версионируется и помещается в Gitlab Container Registry;
2) test - тестирование;
3) release - если тесты пройдены удачно, то полученный на уровне build образ версионируется при помощи crane c тэгом "$CI_COMMIT_SHA" и помещается Gitlab Container Registry
4) Выполняется деплой приложения, используя helm-чарт. 


## Мониторинг. Установка Grafana и Prometheus
Выполнить команды в терминале:

```
cd helm

helm upgrade --atomic --install grafana grafana
kubectl get secret --namespace <namespace_name> grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


helm upgrade --atomic --install prometheus prometheus
kubectl get pods -l "app.kubernetes.io/instance=prometheus"
```

Доступ к веб-интрефейсам осуществляется перенаправлением портов на localhost (порт 3000 для Grafana, порт 9090 для Prometheus).



____________________________________________________________________________________________________________________________________________________
#### * Для запуска приложения локально:
Frontend:
```bash
cd frontend/
npm install
NODE_ENV=production VUE_APP_API_URL=http://localhost:8081 npm run serve
```
Backend:
```bash
cd backend/
go run ./cmd/api
go test -v ./... 
```
