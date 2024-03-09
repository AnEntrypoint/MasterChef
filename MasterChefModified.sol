// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "masterchefcontracts/token/ERC20/SafeERC20.sol";
import "masterchefcontracts/access/Ownable.sol";
import "masterchefcontracts/math/SafeMath.sol";
import "SushiToken.sol";

// MasterChef is the master of Sushi. He can make Sushi and he is a fair guy.
contract MasterChefModefied is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Tokens to distribute per block.
        uint256 lastRewardBlock; // Last block number that Tokens distribution occurs.
        uint256 accTokenPerShare; // Accumulated Tokens per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    // The LINK TOKEN!
    SushiToken public link;
    // Dev address.
    // address public feeCollector;
    // LINK tokens created per block.
    uint256 public linkPerBlock;
    // Bonus muliplier for early link makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when LINK mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(SushiToken _link, address _feeAddress, uint256 _linkPerBlock) public {
        link = _link;
        feeAddress = _feeAddress;
        linkPerBlock = _linkPerBlock;
        startBlock = block.number;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        // require(
        //     _depositFeeBP <= 10000,
        //     "add: invalid deposit fee basis points"
        // );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTokenPerShare: 0,
                depositFeeBP: _depositFeeBP
            })
        );
    }

    // Update the given pool's LINK allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        // require(
        //     _depositFeeBP <= 10000,
        //     "set: invalid deposit fee basis points"
        // );
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending Tokens on frontend.
    function pendingTokens(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 linkReward = multiplier
                .mul(linkPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(
                linkReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 linkReward = multiplier
            .mul(linkPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        link.mint(feeAddress, linkReward.div(10));
        link.mint(address(this), linkReward);
        pool.accTokenPerShare = pool.accTokenPerShare.add(
            linkReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for LINK allocation.

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accTokenPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeLINKTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeLINKTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe link transfer function, just in case if rounding error causes pool to not have enough Tokens.
    function safeLINKTransfer(address _to, uint256 _amount) internal {
        uint256 linkBal = link.balanceOf(address(this));
        if (_amount > linkBal) {
            link.transfer(_to, linkBal);
        } else {
            link.transfer(_to, _amount);
        }
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        // require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    function updateEmissionRate(uint256 _linkPerBlock) public onlyOwner {
        massUpdatePools();
        linkPerBlock = _linkPerBlock;
    }

    function rewardWithdraw(uint256 _amount) public onlyOwner {
        safeLINKTransfer(msg.sender, _amount);
    }
}
