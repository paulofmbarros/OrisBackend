#!/bin/bash
# Start the backend
echo "Starting backend..."
dotnet run --project src/Oris.Api/Oris.WebApplication/Oris.WebApplication.csproj --urls "http://localhost:5134" > tmp/backend.log 2>&1 &
PID=$!
echo "Backend started with PID $PID"

# Wait for it to be ready
echo "Waiting for health check..."
for i in {1..30}; do
  if curl -s http://localhost:5134/health | grep -q "Healthy"; then
    echo "Backend is ready!"
    break
  fi
  sleep 1
done

# Run Postman Collection (I will use the tool for this part, so I'll exit here and let the agent call the tool)
# But wait, I can't call the tool from inside the script.
# So I will just start the server here, and I'll keep track of the PID to kill it later.
# Actually, I should just run the server as a background process using run_shell_command and then cleanup later.
