resource "aws_launch_configuration" "agent-lc" {
    name_prefix = "agent-lc-"
    image_id = "ami-bb9a6bc2"
    instance_type = "t2.micro"
    user_data = "sudo yum -y update "

    lifecycle {
        create_before_destroy = true
    }

    root_block_device {
        volume_type = "gp2"
        volume_size = "50"
    }
}
resource "aws_autoscaling_group" "workers" {
    availability_zones = ["eu-west-1a"]
    vpc_zone_identifier = ["subnet-062a5361"]
    name = "workers"
    max_size = "20"
    min_size = "1"
    health_check_grace_period = 300
    health_check_type = "EC2"
    desired_capacity = 2
    force_delete = true
    launch_configuration = "${aws_launch_configuration.agent-lc.name}"

    tag {
        key = "Name"
        value = "worker Instance"
        propagate_at_launch = true
    }
}

resource "aws_autoscaling_group" "managers" {
    availability_zones = ["eu-west-1c"]
    vpc_zone_identifier = ["subnet-2151eb7a"]
    name = "managers"
    max_size = "20"
    min_size = "1"
    health_check_grace_period = 300
    health_check_type = "EC2"
    desired_capacity = 2
    force_delete = true
    launch_configuration = "${aws_launch_configuration.agent-lc.name}"

    tag {
        key = "Name"
        value = "manager Instance"
        propagate_at_launch = true
    }
}
