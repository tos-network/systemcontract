// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../contracts/KycManager.sol";

contract KycManagerTest is Test {
    KycManager public kycManager;
    
    address public admin1;
    address public admin2;
    address public operator1;
    address public operator2;
    address public user1;
    address public user2;

    uint256 constant REGION_1 = 1;
    uint256 constant REGION_2 = 2;
    uint8 constant KYC_LEVEL_1 = 1;
    uint8 constant KYC_LEVEL_2 = 2;

    // Events
    event RegionAdd(uint256 indexed regionId);
    event RegionDel(uint256 indexed regionId);
    event AdminAdd(uint256 indexed regionId, address indexed admin);
    event AdminDel(uint256 indexed regionId, address indexed admin);
    event OpAdd(uint256 indexed regionId, address indexed op);
    event OpDel(uint256 indexed regionId, address indexed op);
    event KYCUpdate(
        address indexed user,
        uint8 oldLevel,
        uint8 newLevel,
        uint256 indexed regionId,
        address indexed operator
    );
    event RegionPaused(uint256 indexed regionId, bool paused);

    function setUp() public {
        // Setup test addresses
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");
        operator1 = makeAddr("operator1");
        operator2 = makeAddr("operator2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contract
        kycManager = new KycManager();
        
        // Ensure test runs with globalAdmin permissions
        vm.startPrank(kycManager.globalAdmin());
    }

    function test_Deployment() public {
        assertEq(kycManager.globalAdmin(), kycManager.KYC_ADMINOR_ADDR());
        assertEq(uint256(kycManager.contractState()), 0); // Active = 0
    }

    function test_RegionManagement() public {
        vm.expectEmit(true, false, false, true);
        emit RegionAdd(REGION_1);
        kycManager.addRegionId(REGION_1);

        // Test non-admin access
        vm.stopPrank();
        vm.prank(admin1);
        vm.expectRevert(bytes("NotGlobal"));
        kycManager.addRegionId(REGION_1);

        // Test region removal
        vm.prank(kycManager.globalAdmin());
        vm.expectEmit(true, false, false, true);
        emit RegionDel(REGION_1);
        kycManager.removeRegionId(REGION_1);
    }

    function test_AdminManagement() public {
        kycManager.addRegionId(REGION_1);

        vm.expectEmit(true, true, false, true);
        emit AdminAdd(REGION_1, admin1);
        kycManager.addRegionAdmin(REGION_1, admin1);

        // Test zero address
        vm.expectRevert(bytes("Zero"));
        kycManager.addRegionAdmin(REGION_1, address(0));

        // Test admin removal
        vm.expectEmit(true, true, false, true);
        emit AdminDel(REGION_1, admin1);
        kycManager.removeRegionAdmin(REGION_1, admin1);
    }

    function test_OperatorManagement() public {
        kycManager.addRegionId(REGION_1);
        kycManager.addRegionAdmin(REGION_1, admin1);

        // Test operator addition by admin
        vm.stopPrank();
        vm.prank(admin1);
        vm.expectEmit(true, true, false, true);
        emit OpAdd(REGION_1, operator1);
        kycManager.addRegionOperator(REGION_1, operator1);

        // Test non-admin access
        vm.prank(operator1);
        vm.expectRevert(bytes("NoPerm"));
        kycManager.addRegionOperator(REGION_1, operator2);
    }

    function test_KYCManagement() public {
        kycManager.addRegionId(REGION_1);
        kycManager.addRegionAdmin(REGION_1, admin1);
        
        vm.stopPrank();
        vm.prank(admin1);
        kycManager.addRegionOperator(REGION_1, operator1);

        // Test KYC level setting
        vm.prank(operator1);
        vm.expectEmit(true, false, true, true);
        emit KYCUpdate(user1, 0, KYC_LEVEL_1, REGION_1, operator1);
        kycManager.setKYCLevel(user1, KYC_LEVEL_1, REGION_1);

        // Test non-operator access
        vm.prank(user2);
        vm.expectRevert("NotOp");
        kycManager.setKYCLevel(user1, KYC_LEVEL_1, REGION_1);
    }

    function test_PauseFunctionality() public {
        kycManager.addRegionId(REGION_1);
        kycManager.addRegionAdmin(REGION_1, admin1);
        
        vm.stopPrank();
        vm.prank(admin1);
        kycManager.addRegionOperator(REGION_1, operator1);

        // Test global pause
        vm.prank(kycManager.globalAdmin());
        kycManager.toggleContractState();
        assertEq(uint256(kycManager.contractState()), 1); // Paused = 1

        // Test region pause
        vm.prank(admin1);
        kycManager.toggleRegionState(REGION_1);
        assertTrue(kycManager.isRegionPaused(REGION_1));

        // Test KYC updates when globally paused
        vm.prank(operator1);
        vm.expectRevert(bytes("Paused"));
        kycManager.setKYCLevel(user1, KYC_LEVEL_1, REGION_1);

        // Reset global state and test region pause
        vm.prank(kycManager.globalAdmin());
        kycManager.toggleContractState();
        vm.prank(operator1);
        vm.expectRevert(bytes("RegionPaused"));
        kycManager.setKYCLevel(user1, KYC_LEVEL_1, REGION_1);
    }

    function test_QueryFunctions() public {
        kycManager.addRegionId(REGION_1);
        kycManager.addRegionAdmin(REGION_1, admin1);
        
        vm.stopPrank();
        vm.prank(admin1);
        kycManager.addRegionOperator(REGION_1, operator1);

        // Test admin status queries
        assertTrue(kycManager.isRegionAdmin(REGION_1, admin1));
        assertFalse(kycManager.isRegionAdmin(REGION_1, operator1));

        // Test operator status queries
        assertTrue(kycManager.isRegionOperator(REGION_1, operator1));
        assertFalse(kycManager.isRegionOperator(REGION_1, admin1));

        // Test pause status queries
        assertFalse(kycManager.isRegionPaused(REGION_1));
        vm.prank(admin1);
        kycManager.toggleRegionState(REGION_1);
        assertTrue(kycManager.isRegionPaused(REGION_1));
    }

}