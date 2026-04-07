# (run locally, in the repo)
cd backend
npm install          # creates package-lock.json
cd ..
git add backend/package-lock.json
git commit -m "Add lock file for reproducible builds"
git push origin main
