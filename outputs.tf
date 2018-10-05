output "lambda_function_name" {
  value = "${aws_lambda_function.ebs_attach.name}"
}

output "lambda_function_arn" {
  value = "${aws_lambda_function.ebs_attach.arn}"
}
