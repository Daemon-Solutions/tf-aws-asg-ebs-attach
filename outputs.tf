output "lambda_function_name" {
  value = "${module.lambda.function_name}"
}

output "lambda_function_arn" {
  value = "${module.lambda.function_arn}"
}

output "lamda_role_arn" {
  value = "${module.lambda.role_arn}"
}

output "lamda_role_name" {
  value = "${module.lambda.role_name}"
}
