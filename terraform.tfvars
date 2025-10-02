resource_group_name = "rg-airflow-prod"
location            = "East US"
vnet_name           = "vnet-airflow"
db_admin_user       = "airflowadmin"
db_admin_password = "airflow_pass"
airflow_image_tag   = "2.7.1"
dags_git_repo       = "git@github.com:meu-org/airflow-dags.git"
dags_git_branch     = "main"

ssh_private_key   = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC46Ey1Qyjkl26NWAlG7v5VsayovUANpE6AyV88ookk8AAAAJhklC0MZJQt
DAAAAAtzc2gtZWQyNTUxOQAAACC46Ey1Qyjkl26NWAlG7v5VsayovUANpE6AyV88ookk8A
AAAEBjrAS5yAt4OmmiYE8sbg6V8FcIFnlWL6nEmir80YhcFLjoTLVDKOSXbo1YCUbu/lWx
rKi9QA2kToDJXzyiiSTwAAAAEGFpcmZsb3ctZ2l0LXN5bmMBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
EOF

ssh_known_hosts     = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="



