FROM golang

ENV dep_version=0.5.1
ENV tf_version=0.11.13

RUN apt update && apt -y install unzip python3-pip && pip3 install boto3
RUN curl -L -s https://github.com/golang/dep/releases/download/v${dep_version}/dep-linux-amd64 -o /bin/dep && chmod +x /bin/dep
RUN curl -L -s https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_linux_amd64.zip -o /tmp/terraform.zip \
   && unzip /tmp/terraform.zip -d /bin \
   && chmod +x /bin/terraform && rm -rf /tmp/terraform.zip

WORKDIR /go/src/tf-aws-asg-ebs-attach/test

CMD dep ensure -v && go test -v
