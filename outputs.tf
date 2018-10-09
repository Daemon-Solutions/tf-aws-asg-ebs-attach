output "lambda_function_name" {
  value = "${aws_lambda_function.ebs_attach.function_name}"
}

output "lambda_function_arn" {
  value = "${aws_lambda_function.ebs_attach.arn}"
}
