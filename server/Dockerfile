# Use a base image with GCC and make installed
FROM gcc:latest

# Set the working directory inside the container
WORKDIR /app

# Copy the entire server directory content
COPY . .

# Build the server using the Makefile
RUN apt-get update && apt-get install -y libpcap-dev && make

# Expose the port the server listens on
EXPOSE 8000

# Command to run the executable when the container starts
CMD ["./arpahound-server"]
