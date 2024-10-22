// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// OpenZeppelin
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ILaunch} from "./interfaces/ILaunch.sol";

contract LaunchFactory {
    address public immutable LAUNCH_SINGLETON;
    address public immutable INITIAL_OWNER;

    mapping(address => address[]) public launches;

    event LaunchCreated(address indexed user, address indexed launch);

    constructor(address owner_, address singleton_) {
        INITIAL_OWNER = owner_;
        LAUNCH_SINGLETON = singleton_;
    }

    function createLaunch(ILaunch.InitializeParams memory params_) public {
        address launch = Clones.clone(LAUNCH_SINGLETON);

        ILaunch(launch).initialize(params_);

        launches[msg.sender].push(launch);

        emit LaunchCreated(INITIAL_OWNER, launch);
    }

    function getLaunches(address user) public view returns (address[] memory) {
        return launches[user];
    }
}
