IMAGENAME=tf-aws-asg-ebs-attach

check-%:
	@ if [ "${${*}}" = "" ]; then echo "Environment variable $(*) not set"; exit 1; fi

.PHONY: docker
docker:
	@docker images | grep -q ^$(IMAGENAME) || docker build -t $(IMAGENAME) .

.PHONY: test
test: check-AWS_SESSION_TOKEN check-AWS_SECRET_ACCESS_KEY check-AWS_ACCESS_KEY_ID docker
	@rm -rf examples/.terraform/modules examples/terraform.tfstate*
	@docker run --rm -v $(PWD):/go/src/tf-aws-asg-ebs-attach \
		-e AWS_SESSION_TOKEN \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_ACCESS_KEY_ID \
		$(IMAGENAME)
	# fix permissions
	@docker run --rm -v $(PWD):/go/src/tf-aws-asg-ebs-attach \
		$(IMAGENAME) chown $$(id -u):$$(id -g) -R /go/src/tf-aws-asg-ebs-attach
