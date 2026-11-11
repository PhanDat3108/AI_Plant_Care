# Làm việc nhóm

Trưởng nhóm dùng GitHub CLI đã đăng nhập. Từ gốc repo, kiểm tra `git remote -v`, `git status` và `gh auth status`. Khi chưa có remote và tên repo còn trống:

```sh
gh repo create ai-plant-care --private --source=. --remote=origin --push
```

Nếu repo cùng tên đã tồn tại, kiểm tra chủ sở hữu và lịch sử trước khi kết nối. Trên GitHub mở repository → Settings → Collaborators (hoặc Collaborators and teams) → Add people, nhập username từng thành viên và gửi lời mời. Thành viên chấp nhận rồi clone.

```sh
git clone https://github.com/OWNER/ai-plant-care.git
cd ai-plant-care
git switch main
git pull --ff-only
git switch -c feat/lich-tuoi
# Sau khi sửa và kiểm thử, chọn từng file bằng git add
git add docs/API.md
git diff --cached
git commit -m "docs: cập nhật hợp đồng lịch tưới"
git push -u origin feat/lich-tuoi
```

Dùng feat/ cho tính năng, fix/ cho sửa lỗi. Tạo Pull Request vào main, điền template và chỉ định reviewer. Reviewer kiểm tra ownership, hợp đồng, xử lý lỗi và kết quả CI trước khi merge. Nếu conflict, trên branch cá nhân chạy `git fetch origin`, `git merge origin/main`, mở file conflict, thống nhất nội dung, git add các file đã giải quyết, chạy test, commit và push. Không force-push main.

Gợi ý chia issue: mobile scan + test camera thật; backend scan history và storage private; CRUD vườn trên Flutter; lịch chăm sóc và thông báo local; kiểm thử adapter thật và CI. Mỗi issue mô tả đầu vào, kết quả mong đợi và cách demo.
