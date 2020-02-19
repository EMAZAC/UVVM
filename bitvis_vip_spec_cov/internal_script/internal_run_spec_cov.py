import subprocess
import os

test_list = [
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-p", "../sim/pc_1.csv", "-s", "../sim/sc_1.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_2.csv", "-s", "../sim/sc_2.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_3.csv", "-s", "../sim/sc_3.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_4.csv", "-s", "../sim/sc_4.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_5.csv", "-s", "../sim/sc_5.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_6.csv", "-s", "../sim/sc_6.csv"],
            ["python3", "../script/run_spec_cov.py", "--strictness", "0", "-r", "../internal_tb/internal_req_file.csv", "-p", "../sim/pc_7.csv", "-s", "../sim/sc_7.csv"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_1_strict_0.txt"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_1_strict_1.txt"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_1_strict_2.txt"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_2_strict_0.txt"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_2_strict_1.txt"],
            ["python3", "../script/run_spec_cov.py", "--config", "../internal_tb/internal_cfg_2_strict_2.txt"]
            ]


def remove_specification_coverage_files():
    for filename in os.listdir("."):
        if filename[0:2] == "sc_":
            if filename.endswith(".csv"):
                print("Removing : %s" %(filename))
                os.remove(filename)

def run_tests():
    for test in test_list:
        process = subprocess.Popen(test, stderr=subprocess.PIPE)
        process.wait()




remove_specification_coverage_files()
run_tests()
