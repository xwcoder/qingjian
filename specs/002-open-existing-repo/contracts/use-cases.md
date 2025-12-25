# Use Cases Contract: 打开已有仓库（添加已有仓库）

本文件定义共享核心对外提供的“用例接口”（不包含 UI 实现），供 macOS/iOS 平台层调用。接口命名与语义必须跨端一致，并满足“新建仓库零回归”。

---

## Repo Management（本功能增量）

### UC-Repo-00: Create Repo（新建仓库）

- **Goal**: 将用户选择的目录初始化为青简仓库（确保元信息存在），并加入仓库列表
- **Input**: `rootURL`, `displayName?`
- **Output**: `RepoSummary`
- **Errors**: `InvalidRepo`, `PermissionDenied`, `AlreadyAdded`, `IOError`
- **Notes**:
  - 若目录已包含有效元信息，可视为“已初始化”，允许幂等成功（不重复添加）
  - 必须确保 `.qingjian_metadata.json` 存在（不存在则写入默认元信息）

### UC-Repo-01: Open Repo（打开已有仓库）

- **Goal**: 将一个“已存在且可识别”的仓库加入仓库列表并可打开
- **Input**: `rootURL`, `displayName?`
- **Output**: `RepoSummary`
- **Errors**: `InvalidRepo`, `PermissionDenied`, `AlreadyAdded`
- **Notes**:
  - 必须校验 `.qingjian_metadata.json` 存在且可解析；否则失败且不入库
  - 幂等：同一路径/同一仓库标识重复打开不产生重复项，应定位到已有条目

### UC-Repo-02: Remove Repo（移除仓库）

- **Input**: `repoId`
- **Output**: `Void`
- **Errors**: `RepoNotFound`
- **Notes**: 仅移除“列表引用/授权”，不删除磁盘文件

### UC-Repo-03: List Repos（列出仓库）

- **Input**: `Void`
- **Output**: `[RepoSummary]`（按最近打开排序）
- **Notes**: 结果应反映可用性（路径/授权失效时为不可用）

### UC-Repo-04: Validate Repo Metadata（校验仓库元信息）

- **Goal**: 对 UI 的文件选择结果进行快速校验（用于错误提示与避免错误入库）
- **Input**: `rootURL`
- **Output**: `Void`
- **Errors**: `InvalidRepo`, `PermissionDenied`, `IOError`
- **Notes**: 该用例只做校验，不产生副作用（不写入元信息、不写入 registry）


