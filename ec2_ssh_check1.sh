#!/bin/bash
#!/bin/bash

# SSH into the EC2 instance
ssh -i /path/to/your/key.pem ec2-user@<EC2_Instance_IP> <<'ENDSSH'

# Commands to run after SSH login
# Display system information
echo "System information:"
uname -a

# Display CPU information
echo "CPU information:"
cat /proc/cpuinfo

# Display memory information
echo "Memory information:"
free -h

# Display disk usage
echo "Disk usage:"
df -h

# Display network information
echo "Network information:"
ip a

# Exit the SSH session
exit

ENDSSH
