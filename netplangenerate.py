# Script to generate proxy list

# Define the base information
username = "vodkaace"
country = "indonesia"
port = 3128
start_ip = 1
end_ip = 254
base_ip = "89.144.7."

# Open the file to save the generated proxy list
with open("proxy_list.txt", "w") as file:
    for i in range(start_ip, end_ip + 1):
        ip = f"{base_ip}{i}"
        proxy = f"{username}:{country}:{ip}:{port}"
        file.write(proxy + "\n")

print("Proxy list generated successfully.")
