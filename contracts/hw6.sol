// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1. 
library ArrayLibrary {
    function indexOf(uint256[] storage arr, uint256 value) internal view returns (bool found, uint256 index) {
        uint256 len = arr.length;
        for (uint256 i = 0; i < len; i++) {
            if (arr[i] == value) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function binarySearch(uint256[] storage arr, uint256 value) internal view returns (bool found, uint256 index) {
        uint256 low = 0;
        uint256 high = arr.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            uint256 current = arr[mid];
            if (current == value) {
                return (true, mid);
            }
            if (current < value) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return (false, 0);
    }

    function sort(uint256[] storage arr) internal {
        uint256 len = arr.length;
        uint256[] memory tmp = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            tmp[i] = arr[i];
        }
        for (uint256 i = 1; i < len; i++) {
            uint256 key = tmp[i];
            uint256 j = i;
            while (j > 0 && tmp[j - 1] > key) {
                tmp[j] = tmp[j - 1];
                j--;
            }
            tmp[j] = key;
        }
        for (uint256 i = 0; i < len; i++) {
            arr[i] = tmp[i];
        }
    }

    function removeAt(uint256[] storage arr, uint256 index) internal {
        require(index < arr.length, "Index out of bounds");
        for (uint256 i = index; i < arr.length - 1; i++) {
            arr[i] = arr[i + 1];
        }
        arr.pop();
    }

    function removeValue(uint256[] storage arr, uint256 value) internal returns (bool) {
        (bool found, uint256 index) = indexOf(arr, value);
        if (!found) {
            return false;
        }
        removeAt(arr, index);
        return true;
    }
}

contract ArrayUtils {
    using ArrayLibrary for uint256[];

    uint256[] private data;

    event ElementAdded(uint256 value);
    event ElementRemoved(uint256 value);
    event ArraySorted();

    function add(uint256 value) external {
        data.push(value);
        emit ElementAdded(value);
    }

    function find(uint256 value) external view returns (bool found, uint256 index) {
        return data.indexOf(value);
    }

    function findSorted(uint256 value) external view returns (bool found, uint256 index) {
        return data.binarySearch(value);
    }

    function sortArray() external {
        data.sort();
        emit ArraySorted();
    }

    function removeAtIndex(uint256 index) external {
        uint256 value = data[index];
        data.removeAt(index);
        emit ElementRemoved(value);
    }

    function removeByValue(uint256 value) external {
        require(data.removeValue(value), "Value not found");
        emit ElementRemoved(value);
    }

    function getAll() external view returns (uint256[] memory) {
        return data;
    }

    function length() external view returns (uint256) {
        return data.length;
    }
}

// 2.
contract GrandmaGifts {
    struct Grandchild {
        uint256 birthday;
        bool registered;
        bool claimed;
    }

    address public immutable grandma;
    address[] public grandchildren;
    mapping(address => Grandchild) public info;

    uint256 public giftAmount;
    bool public funded;

    event Deposited(address indexed grandma, uint256 total, uint256 giftPerGrandchild, uint256 refunded);
    event GiftClaimed(address indexed grandchild, uint256 amount);

    modifier onlyGrandma() {
        require(msg.sender == grandma, "Only grandma");
        _;
    }

    constructor(address[] memory wallets, uint256[] memory birthdays) {
        require(wallets.length > 0, "No grandchildren");
        require(wallets.length == birthdays.length, "Length mismatch");
        grandma = msg.sender;
        for (uint256 i = 0; i < wallets.length; i++) {
            require(wallets[i] != address(0), "Zero address");
            require(!info[wallets[i]].registered, "Duplicate grandchild");
            info[wallets[i]] = Grandchild(birthdays[i], true, false);
            grandchildren.push(wallets[i]);
        }
    }

    function deposit() external payable onlyGrandma {
        require(!funded, "Already funded");
        uint256 count = grandchildren.length;
        require(msg.value >= count, "Deposit too small");
        giftAmount = msg.value / count;
        funded = true;
        uint256 remainder = msg.value - giftAmount * count;
        if (remainder > 0) {
            (bool ok, ) = grandma.call{value: remainder}("");
            require(ok, "Refund failed");
        }
        emit Deposited(msg.sender, msg.value, giftAmount, remainder);
    }

    function claim() external {
        Grandchild storage g = info[msg.sender];
        require(g.registered, "Not a grandchild");
        require(funded, "Not funded yet");
        require(!g.claimed, "Already claimed");
        require(block.timestamp >= g.birthday, "Birthday has not come yet");
        g.claimed = true;
        (bool ok, ) = msg.sender.call{value: giftAmount}("");
        require(ok, "Transfer failed");
        emit GiftClaimed(msg.sender, giftAmount);
    }

    function grandchildrenCount() external view returns (uint256) {
        return grandchildren.length;
    }
}

// 3.
contract EducationGrantFund {
    struct Milestone {
        string name;
        uint256 shareBps;
        uint256 deadline;
        bool confirmed;
    }

    struct Student {
        bool registered;
        bool frozen;
        uint256 totalFunded;
        uint256 allocated;
        uint256 pending;
        Milestone[] milestones;
    }

    address public owner;
    mapping(address => Student) private students;

    event StudentRegistered(address indexed student, uint256 milestonesCount);
    event Funded(address indexed student, address indexed donor, uint256 amount);
    event MilestoneConfirmed(address indexed student, uint256 indexed milestoneId, uint256 grade, bool onTime, uint256 amount);
    event GrantPaid(address indexed student, uint256 amount);
    event StudentFrozen(address indexed student, string reason);
    event StudentUnfrozen(address indexed student);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier studentExists(address student) {
        require(students[student].registered, "Student not registered");
        _;
    }

    modifier notFrozen(address student) {
        require(!students[student].frozen, "Student is frozen");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function registerStudent(
        address student,
        string[] calldata names,
        uint256[] calldata sharesBps,
        uint256[] calldata deadlines
    ) external onlyOwner {
        require(!students[student].registered, "Already registered");
        require(names.length > 0, "No milestones");
        require(names.length == sharesBps.length && names.length == deadlines.length, "Length mismatch");
        uint256 sum;
        Student storage s = students[student];
        s.registered = true;
        for (uint256 i = 0; i < names.length; i++) {
            sum += sharesBps[i];
            s.milestones.push(Milestone(names[i], sharesBps[i], deadlines[i], false));
        }
        require(sum <= 10000, "Shares exceed 100%");
        emit StudentRegistered(student, names.length);
    }

    function fund(address student) external payable studentExists(student) {
        require(msg.value > 0, "Zero amount");
        students[student].totalFunded += msg.value;
        emit Funded(student, msg.sender, msg.value);
    }

    function confirmMilestone(address student, uint256 milestoneId, uint256 grade)
        external
        onlyOwner
        studentExists(student)
    {
        require(grade <= 100, "Grade must be 0-100");
        Student storage s = students[student];
        require(milestoneId < s.milestones.length, "Invalid milestone");
        Milestone storage m = s.milestones[milestoneId];
        require(!m.confirmed, "Already confirmed");
        m.confirmed = true;

        bool onTime = block.timestamp <= m.deadline;
        uint256 amount = (s.totalFunded * m.shareBps * grade) / (10000 * 100);
        if (!onTime) {
            amount = amount / 2;
        }
        uint256 available = s.totalFunded - s.allocated;
        if (amount > available) {
            amount = available;
        }
        s.allocated += amount;
        s.pending += amount;
        emit MilestoneConfirmed(student, milestoneId, grade, onTime, amount);

        if (!s.frozen) {
            _payout(student);
        }
    }

    function freezeStudent(address student, string calldata reason) external onlyOwner studentExists(student) {
        students[student].frozen = true;
        emit StudentFrozen(student, reason);
    }

    function unfreezeStudent(address student) external onlyOwner studentExists(student) {
        students[student].frozen = false;
        emit StudentUnfrozen(student);
        _payout(student);
    }

    function withdrawPending() external studentExists(msg.sender) notFrozen(msg.sender) {
        require(students[msg.sender].pending > 0, "Nothing to withdraw");
        _payout(msg.sender);
    }

    function _payout(address student) private {
        Student storage s = students[student];
        uint256 amount = s.pending;
        if (amount == 0) {
            return;
        }
        s.pending = 0;
        (bool ok, ) = student.call{value: amount}("");
        require(ok, "Transfer failed");
        emit GrantPaid(student, amount);
    }

    function getStudent(address student)
        external
        view
        returns (bool frozen, uint256 totalFunded, uint256 allocated, uint256 pending, uint256 milestonesCount)
    {
        Student storage s = students[student];
        return (s.frozen, s.totalFunded, s.allocated, s.pending, s.milestones.length);
    }

    function getMilestone(address student, uint256 id)
        external
        view
        returns (string memory name, uint256 shareBps, uint256 deadline, bool confirmed)
    {
        Milestone storage m = students[student].milestones[id];
        return (m.name, m.shareBps, m.deadline, m.confirmed);
    }
}

// 4.
contract EmergencyFund {
    enum Purpose {
        Medical,
        Accident,
        Disaster
    }

    struct Request {
        address requester;
        address payable beneficiary;
        uint256 amount;
        Purpose purpose;
        string description;
        uint256 approvals;
        bool approvedByOrg;
        bool executed;
        bool cancelled;
    }

    address public owner;
    address public medicalOrg;
    uint256 public monthlyContribution;
    uint256 public requiredApprovals;
    uint256 public constant PERIOD = 30 days;

    address[] public members;
    mapping(address => bool) public isMember;
    mapping(address => uint256) public lastPaid;
    mapping(address => uint256) public totalContributed;

    Request[] private requests;
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    event MemberAdded(address indexed member);
    event Contributed(address indexed member, uint256 amount);
    event RequestCreated(uint256 indexed id, address indexed requester, address indexed beneficiary, uint256 amount, Purpose purpose);
    event RequestApproved(uint256 indexed id, address indexed approver, uint256 approvals);
    event RequestExecuted(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event RequestCancelled(uint256 indexed id);
    event MedicalOrgChanged(address indexed newOrg);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only member");
        _;
    }

    modifier requestOpen(uint256 id) {
        require(id < requests.length, "Invalid request");
        require(!requests[id].executed && !requests[id].cancelled, "Request closed");
        _;
    }

    constructor(address[] memory initialMembers, uint256 monthlyContribution_, uint256 requiredApprovals_, address medicalOrg_) {
        require(initialMembers.length > 0, "No members");
        require(requiredApprovals_ > 0 && requiredApprovals_ <= initialMembers.length, "Invalid threshold");
        require(monthlyContribution_ > 0, "Zero contribution");
        owner = msg.sender;
        monthlyContribution = monthlyContribution_;
        requiredApprovals = requiredApprovals_;
        medicalOrg = medicalOrg_;
        for (uint256 i = 0; i < initialMembers.length; i++) {
            _addMember(initialMembers[i]);
        }
    }

    function _addMember(address member) private {
        require(member != address(0), "Zero address");
        require(!isMember[member], "Already member");
        isMember[member] = true;
        members.push(member);
        emit MemberAdded(member);
    }

    function addMember(address member) external onlyOwner {
        _addMember(member);
    }

    function setMedicalOrg(address org) external onlyOwner {
        medicalOrg = org;
        emit MedicalOrgChanged(org);
    }

    function contribute() external payable onlyMember {
        require(msg.value >= monthlyContribution, "Below monthly contribution");
        require(lastPaid[msg.sender] == 0 || block.timestamp >= lastPaid[msg.sender] + PERIOD, "Already paid this month");
        lastPaid[msg.sender] = block.timestamp;
        totalContributed[msg.sender] += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function createRequest(address payable beneficiary, uint256 amount, Purpose purpose, string calldata description)
        external
        onlyMember
        returns (uint256 id)
    {
        require(beneficiary != address(0), "Zero address");
        require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        id = requests.length;
        requests.push(Request(msg.sender, beneficiary, amount, purpose, description, 0, false, false, false));
        emit RequestCreated(id, msg.sender, beneficiary, amount, purpose);
    }

    function approve(uint256 id) external requestOpen(id) {
        Request storage r = requests[id];
        require(!hasApproved[id][msg.sender], "Already approved");
        if (msg.sender == medicalOrg) {
            r.approvedByOrg = true;
        } else {
            require(isMember[msg.sender], "Not allowed to approve");
            require(msg.sender != r.requester, "Requester cannot approve");
            r.approvals += 1;
        }
        hasApproved[id][msg.sender] = true;
        emit RequestApproved(id, msg.sender, r.approvals);

        if (r.approvedByOrg || r.approvals >= requiredApprovals) {
            _execute(id);
        }
    }

    function cancelRequest(uint256 id) external requestOpen(id) {
        Request storage r = requests[id];
        require(msg.sender == r.requester || msg.sender == owner, "Not allowed");
        r.cancelled = true;
        emit RequestCancelled(id);
    }

    function _execute(uint256 id) private {
        Request storage r = requests[id];
        require(r.amount <= address(this).balance, "Insufficient fund balance");
        r.executed = true;
        (bool ok, ) = r.beneficiary.call{value: r.amount}("");
        require(ok, "Transfer failed");
        emit RequestExecuted(id, r.beneficiary, r.amount);
    }

    function getRequest(uint256 id) external view returns (Request memory) {
        return requests[id];
    }

    function requestsCount() external view returns (uint256) {
        return requests.length;
    }

    function membersCount() external view returns (uint256) {
        return members.length;
    }

    function fundBalance() external view returns (uint256) {
        return address(this).balance;
    }
}


