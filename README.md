# Todo (iOS Demo)

This app is a simple todo list. Its main purpose is to demonstrate the usage of the [`SecureKeyValueStorage`](https://apppets.github.io/PrivacyKit/iphone/public/Classes/SecureKeyValueStorage.html) class. The tasks are stored "in the cloud" on a [P-Service](https://github.com/AppPETs/PrivacyService). The tasks are encrypted in such a way that the P-Service operator can neither access your tasks (confidentiality) nor manipulate them (integrity). Tasks can be synchronised between multiple devices.

⚠️ If you use the demo service at https://services.app-pets.org, which is the default, **all requests are logged** in order to demonstrate the information collected by a potentially malicious service operator. Your IP address will be hidden by a Shalon¹ proxy server. **Do not use this in productive apps.** There is no guarantee of availability for tasks stored with the demo service.

<img src="https://raw.githubusercontent.com/AppPETs/Todo-iOS/master/Mockups/01-todo@3x.png" height="798px" width="400px" alt="User Interface Mockup"/>

## Attacker Model

The attacker is an insider, e.g., the P-Service operator. He can access and manipulate all entries saved to the service, including traffic data (IP address, HTTP headers, etc.). It is impossible for him to break cryptographic systems, as he is limited in his computational complexity.

His goal is to link stored tasks to users or to other tasks.

## Implementation Details

Each task has an ID, which is chosen as close to `0` as possible. One a task is deleted, its ID can be re-used. The successor of the highest task ID is stored at the key-value storage with the value encoded as a 16-bit unsigned integer (big endian) and the key `task_max`. All other tasks are stored with the key `task_<id>`, where `<id>` is the ID of the task. The values are UTF-8 encoded strings containing JSON of the following format:

```json
{
  "description": "<description>",
  "isCompleted": true
}
```

Every single change is directly propagated to the remote key-value storage.

Initially all tasks can be loaded by obtaining `task_max`. All other tasks can be retrieved by iterating over the task IDs between `0 ≤ i < task_max`. It should be considered, that some tasks in that range might not exist, as they could have been deleted previously.

---

1.	A. Panchenko, B. Westermann, L. Pimenidis, and C. Andersson, [**SHALON: Lightweight Anonymization Based on Open Standards**](http://dx.doi.org/10.1109/ICCCN.2009.5235258) in *IEEE ICCCN*, 2009