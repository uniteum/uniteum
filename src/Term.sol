// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

/**
 * @title Term — Unit Term Type
 * @dev Type for unit term operations.
 * Base unit terms are packed into uint:
 * The last two bytes (30, 31) are a rational exponent.
 * Symbolic terms have the first 30 bytes as the base symbol.
 * Address terms have the first byte = 1, and the next 20 bytes are an address.
 * +0......0|1.........................20|21................29|30...........31+
 * | Symbol                                                   |    Exponent   |
 * |----------------------------------------------------------| ± num / den   |
 * | Type=1 | Address [1..20]            | Reserved           |  int8 | uint8 |
 * +255................................96|95................16|15....8|7.....0+
 * Example 1: meter^2\3
 * |6d 6574657200000000000000000000000000000000 000000000000000000 02 03|
 * |  |                                        |                  |  |  |
 * |01 c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 000000000000000000 ff 01|
 * Example 2: [address of WETH]^-1
 */
type Term is uint256;
