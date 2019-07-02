IMAGENAME=tf-aws-asg-ebs-attach
TF_VERSION=0.12.3

check-%:
	@ if [ "${${*}}" = "" ]; then echo "Environment variable $(*) not set"; exit 1; fi

.PHONY: docker
docker:
	@docker inspect $(IMAGENAME):$(TF_VERSION) >/dev/null || docker build --build-arg tf_version=$(TF_VERSION) -t $(IMAGENAME):$(TF_VERSION) .

.PHONY: test
test: check-AWS_SESSION_TOKEN check-AWS_SECRET_ACCESS_KEY check-AWS_ACCESS_KEY_ID docker
	@rm -rf examples/.terraform/modules examples/terraform.tfstate*
	@docker run --rm -v $(PWD):/go/src/tf-aws-asg-ebs-attach \
		-e AWS_SESSION_TOKEN \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_ACCESS_KEY_ID \
		$(IMAGENAME):$(TF_VERSION)
	# fix permissions
	@docker run --rm -v $(PWD):/go/src/tf-aws-asg-ebs-attach \
		$(IMAGENAME):$(TF_VERSION) chown $$(id -u):$$(id -g) -R /go/src/tf-aws-asg-ebs-attach
