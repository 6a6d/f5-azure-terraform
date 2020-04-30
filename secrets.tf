resource "random_id" "server" {
    keepers = {
        ami_id = 1
    }

    byte_length = 8
}