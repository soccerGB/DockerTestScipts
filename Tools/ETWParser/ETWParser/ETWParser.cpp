// ETWParser.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

//Turns the DEFINE_GUID for EventTraceGuid into a const.
#define INITGUID

#include <windows.h>
#include <stdio.h>
#include <comdef.h>
#include <guiddef.h>
#include <wbemidl.h>
#include <wmistr.h>
#include <evntrace.h>
#include <tdh.h>

#pragma comment(lib, "tdh.lib")

#define EventId_HcsRpC_CreateSystem_Start	9755
#define EventId_HcsRpC_CreateSystem_End		14346
#define EventId_UtilityVm_Start_begin		21070
#define EventId_UtilityVm_Start_end			20704
#define EventId_UtilityVm_ConnectToGuestService_being	45833
#define EventId_UtilityVm_ConnectToGuestService_end	47038
#define EventId_HcsRpC_StartSystem_Start	7977
#define EventId_HcsRpC_StartSystem_End		15188
#define EventId_HcsRpC_CreateProcess_Start	22339
#define EventId_HcsRpC_CreateProcess_End	17377
//Microsoft-Windows-Hyper-V-Chipset
#define EventId_ExitBootServices	18601

//{80CE50DE-D264-4581-950D-ABADEEE0D340} Microsoft.Windows.HyperV.Compute
//{51DDFA29-D5C8-4803-BE4B-2ECB715570FE} Name: Microsoft-Windows-Hyper-V-Worker
//{DE9BA731-7F33-4F44-98C9-6CAC856B9F83} Name: Microsoft-Windows-Hyper-V-Chipset
GUID guidHyperVComputeProvider = { 0x80CE50DE, 0xD264, 0x4581,{ 0x95, 0x0D, 0xAB, 0xAD, 0xEE, 0xE0, 0xD3, 0x40 } };
GUID guidHyperVChipSetProvider = { 0xDE9BA731, 0x7F33, 0x4F44,{ 0x98, 0xC9, 0x6C, 0xAC, 0x85, 0x6B, 0x9F, 0x83 } };

typedef struct {
	LONGLONG hnsCreateSytem_Start_begin;
	LONGLONG hnsCreateSytem_Start_end;
	LONGLONG hnsUtilityVM_Start_begin;
	LONGLONG hnsUtilityVM_Start_end;
	LONGLONG hnsConnectToGCS_begin;
	LONGLONG hnsConnectToGCS_end;
	LONGLONG hnsExitBootServices;
	LONGLONG hnsHcsStartSystem_begin;
	LONGLONG hnsHcsStartSystem_end;
	LONGLONG hnsHcsCreateProcess_begin;
	LONGLONG hnsHcsCreateProcess_end;
} BootEventInfoType;

BootEventInfoType BootEventInfo;

static const GUID GUID_NULL =
{ 0x00000000, 0x0000, 0x0000,{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } };

// Strings that represent the source of the event metadata.

WCHAR* pSource[] = { L"XML instrumentation manifest", L"WMI MOF class", L"WPP TMF file" };

// Handle to the trace file that you opened.

TRACEHANDLE g_hTrace = 0;
ULONGLONG g_hnsFirstEventTraceStartTime = 0;

// Prototypes

void WINAPI ProcessEvent(PEVENT_RECORD pEvent);
DWORD GetEventInformation(PEVENT_RECORD pEvent, PTRACE_EVENT_INFO & pInfo);
DWORD PrintPropertyMetadata(TRACE_EVENT_INFO* pInfo, DWORD i, USHORT indent);
bool gbStarted = false;

#define BUFSIZE MAX_PATH
TCHAR LOGFILE_PATH[MAX_PATH];

void printResult()
{
	wprintf(L"Raw event data points in ns\n");

	wprintf(L"hnsCreateSytem_Start_begin= %10I64d\n", BootEventInfo.hnsCreateSytem_Start_begin);
	wprintf(L"hnsUtilityVM_Start_begin  = %10I64d\n", BootEventInfo.hnsUtilityVM_Start_begin);
	wprintf(L"hnsUtilityVM_Start_end    = %10I64d\n", BootEventInfo.hnsUtilityVM_Start_end);
	wprintf(L"hnsConnectToGCS_begin     = %10I64d\n", BootEventInfo.hnsConnectToGCS_begin);
	wprintf(L"hnsExitBootServices       = %10I64d\n", BootEventInfo.hnsExitBootServices);
	wprintf(L"hnsConnectToGCS_end       = %10I64d\n", BootEventInfo.hnsConnectToGCS_end);
	wprintf(L"hnsCreateSytem_Start_end  = %10I64d\n", BootEventInfo.hnsCreateSytem_Start_end);

	wprintf(L"hnsHcsStartSystem_begin   = %10I64d\n", BootEventInfo.hnsHcsStartSystem_begin);
	wprintf(L"hnsHcsStartSystem_end     = %10I64d\n", BootEventInfo.hnsHcsStartSystem_end);
	wprintf(L"hnsHcsCreateProcess_begin = %10I64d\n", BootEventInfo.hnsHcsCreateProcess_begin);
	wprintf(L"hnsHcsCreateProcess_end   = %10I64d\n", BootEventInfo.hnsHcsCreateProcess_end);

	wprintf(L"Calculated results in ms\n");

	//Total UVM prep time before UEFI
	wprintf(L"UtilityVMConfigPrepTime: %10I64d\n", ((BootEventInfo.hnsUtilityVM_Start_begin - BootEventInfo.hnsCreateSytem_Start_begin) +
		  											     (BootEventInfo.hnsConnectToGCS_begin - BootEventInfo.hnsUtilityVM_Start_end))/1000000);
	//Utility VM start time interval
	wprintf(L"UtilityVMStartDuration:  %10I64d\n", (BootEventInfo.hnsUtilityVM_Start_end - BootEventInfo.hnsUtilityVM_Start_begin)/1000000);

	//Booting to Guest
	wprintf(L"ConnectToGCSDuration:    %10I64d\n", (BootEventInfo.hnsConnectToGCS_end - BootEventInfo.hnsConnectToGCS_begin)/1000000);

	// UEFI overhead
	wprintf(L"UEFIOverheadTime:        %10I64d\n", (BootEventInfo.hnsExitBootServices - BootEventInfo.hnsConnectToGCS_begin)/1000000);

	wprintf(L"HcsStartSystemDuration:  %10I64d\n", (BootEventInfo.hnsHcsStartSystem_end - BootEventInfo.hnsHcsStartSystem_begin)/1000000);
	wprintf(L"HcsCreateProcessDuration:%10I64d\n", (BootEventInfo.hnsHcsCreateProcess_end - BootEventInfo.hnsHcsCreateProcess_begin)/1000000);
	wprintf(L"HcsCreateSytemDuration:  %10I64d\n", (BootEventInfo.hnsCreateSytem_Start_end - BootEventInfo.hnsCreateSytem_Start_begin)/1000000);

	// total time from run to prompt
	wprintf(L"TotalHCSTime:            %10I64d\n", (((BootEventInfo.hnsCreateSytem_Start_end - BootEventInfo.hnsCreateSytem_Start_begin)  +
												     (BootEventInfo.hnsHcsStartSystem_end - BootEventInfo.hnsHcsStartSystem_begin) + 
												     (BootEventInfo.hnsHcsCreateProcess_end - BootEventInfo.hnsHcsCreateProcess_begin)) / 1000000));
}

void main(int argc, char* argv[])
{
	ULONG status = ERROR_SUCCESS;
	EVENT_TRACE_LOGFILE trace;
	TRACE_LOGFILE_HEADER* pHeader = &trace.LogfileHeader;

	TCHAR Buffer[BUFSIZE];
	DWORD dwRet;

	if (argc < 2)
	{
		wprintf(L"Usage: ETWParser EtlFilename\nargc = (%d)\n", argc);
		exit(1);
	}

	if (MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, argv[1], -1, LOGFILE_PATH, MAX_PATH) == 0)
	{
		wprintf(L"ETL filename  ETWParser EtlFilename argc = (%d)\n", argc);
		exit(1);
	}

	dwRet = GetCurrentDirectory(BUFSIZE, Buffer);
	if (dwRet == 0)
	{
		wprintf(L"GetCurrentDirectory failed (%lu)\n", GetLastError());
		exit(1);
	}
	wprintf(L"The current runnning dirctory is %ws\n", Buffer);

	// initilaize global structs
	ZeroMemory(&BootEventInfo, sizeof(BootEventInfoType));

	// Identify the log file from which you want to consume events
	// and the callbacks used to process the events and buffers.
	ZeroMemory(&trace, sizeof(EVENT_TRACE_LOGFILE));
	trace.LogFileName = (LPWSTR)LOGFILE_PATH;
	trace.EventRecordCallback = (PEVENT_RECORD_CALLBACK)(ProcessEvent);
	trace.ProcessTraceMode = PROCESS_TRACE_MODE_EVENT_RECORD;

	g_hTrace = OpenTrace(&trace);
	if (INVALID_PROCESSTRACE_HANDLE == g_hTrace)
	{
		wprintf(L"OpenTrace failed with %lu\n", GetLastError());
		wprintf(L"Error code is %lu\n", GetLastError());
		goto cleanup;
	}

	status = ProcessTrace(&g_hTrace, 1, 0, 0);
	if (status != ERROR_SUCCESS && status != ERROR_CANCELLED)
	{
		wprintf(L"ProcessTrace failed with %lu\n", status);
		goto cleanup;
	}

cleanup:
	printResult();

	if (INVALID_PROCESSTRACE_HANDLE != g_hTrace)
	{
		status = CloseTrace(g_hTrace);
	}
}


VOID WINAPI ProcessEvent(PEVENT_RECORD pEvent)
{
	DWORD status = ERROR_SUCCESS;
	HRESULT hr = S_OK;
	PTRACE_EVENT_INFO pInfo = NULL;
	LPWSTR pStringGuid = NULL;

	// Skips the event if it is the event trace header. 
	if (IsEqualGUID(pEvent->EventHeader.ProviderId, EventTraceGuid) &&
		pEvent->EventHeader.EventDescriptor.Opcode == EVENT_TRACE_TYPE_INFO)
	{
		goto cleanup; // Skip this event.
	}

	// Process the event. This example does not process the event data but
	// instead prints the metadata that describes each event.
	if (g_hnsFirstEventTraceStartTime == 0)
	{
		// first event time (hns)
		g_hnsFirstEventTraceStartTime = pEvent->EventHeader.TimeStamp.QuadPart;
	}

	status = GetEventInformation(pEvent, pInfo);
	if (ERROR_SUCCESS != status)
	{
		//wprintf(L"GetEventInformation failed with %lu\n", status);
		goto cleanup;
	}

	//wprintf(L"Decoding source: %s\n", pSource[pInfo->DecodingSource]);
	if (DecodingSourceWPP == pInfo->DecodingSource)
	{
		// This example is not rendering WPP metadata.
		goto cleanup;
	}

	if (IsEqualGUID(pInfo->ProviderGuid, guidHyperVComputeProvider))
	{
		LONGLONG timestamp = pEvent->EventHeader.TimeStamp.QuadPart - g_hnsFirstEventTraceStartTime;

		switch (pInfo->EventDescriptor.Id)
		{
			case EventId_HcsRpC_CreateSystem_Start:
				if (BootEventInfo.hnsCreateSytem_Start_begin ==0 && !gbStarted)
				{
					printf("HcsRpC_CreateSystem_Start\n");
					BootEventInfo.hnsCreateSytem_Start_begin = timestamp * 100;
					gbStarted = true;
				}
				break;
			case EventId_HcsRpC_CreateSystem_End:
				if (BootEventInfo.hnsCreateSytem_Start_end == 0  && gbStarted)
				{
					printf("EventId_HcsRpC_CreateSystem_End\n");
					BootEventInfo.hnsCreateSytem_Start_end = timestamp * 100;
					gbStarted = false;
				}
				break;
			case EventId_UtilityVm_Start_begin:
				if (BootEventInfo.hnsUtilityVM_Start_begin == 0 && gbStarted)
				{
					printf("EventId_UtilityVm_Start_begin\n");
					BootEventInfo.hnsUtilityVM_Start_begin = timestamp * 100;
				}
				break;
			case EventId_UtilityVm_Start_end:
				if (BootEventInfo.hnsUtilityVM_Start_end == 0 && gbStarted)
				{
					printf("EventId_UtilityVm_Start_end\n");
					BootEventInfo.hnsUtilityVM_Start_end = timestamp * 100;
				}
				break;
			case EventId_UtilityVm_ConnectToGuestService_being:
				if (BootEventInfo.hnsConnectToGCS_begin == 0 && gbStarted)
				{
					printf("EventId_UtilityVm_ConnectToGuestService_being\n");
					BootEventInfo.hnsConnectToGCS_begin = timestamp * 100;
				}
				break;
			case EventId_UtilityVm_ConnectToGuestService_end:
				if (BootEventInfo.hnsConnectToGCS_end == 0 && gbStarted)
				{
					printf("EventId_UtilityVm_ConnectToGuestService_end\n");
					BootEventInfo.hnsConnectToGCS_end = timestamp * 100;
				}
				break;
			case EventId_HcsRpC_StartSystem_Start:
				//if (BootEventInfo.hnsHcsStartSystem_begin == 0)
				{
					printf("EventId_HcsRpC_StartSystem_Start\n");
					BootEventInfo.hnsHcsStartSystem_begin = timestamp * 100;
				}
				break;
			case EventId_HcsRpC_StartSystem_End:
				//if (BootEventInfo.hnsHcsStartSystem_end == 0)
				{
					BootEventInfo.hnsHcsStartSystem_end = timestamp * 100;
					printf("EventId_HcsRpC_StartSystem_End\n");
				}
				break;
			case EventId_HcsRpC_CreateProcess_Start:
				if (BootEventInfo.hnsHcsCreateProcess_begin == 0)
				{
					printf("EventId_HcsRpC_CreateProcess_Start\n");
					BootEventInfo.hnsHcsCreateProcess_begin = timestamp * 100;
				}
				break;
			case EventId_HcsRpC_CreateProcess_End:
				if (BootEventInfo.hnsHcsCreateProcess_end == 0)
				{
					printf("EventId_HcsRpC_CreateProcess_End\n");
					BootEventInfo.hnsHcsCreateProcess_end = timestamp * 100;
				}
				break;
			default:
				//wprintf(L"Dont-care event id :%d\n", pInfo->EventDescriptor.Id);
				break;
		}
		goto cleanup;
	}
	else if (IsEqualGUID(pInfo->ProviderGuid, guidHyperVChipSetProvider))
	{
		LONGLONG timestamp = pEvent->EventHeader.TimeStamp.QuadPart - g_hnsFirstEventTraceStartTime;

		if (pInfo->EventDescriptor.Id == EventId_ExitBootServices )
		{
			if (BootEventInfo.hnsExitBootServices == 0 && gbStarted)
			{
				printf("EventId_ExitBootServices\n");
				BootEventInfo.hnsExitBootServices = timestamp * 100;
			}
			goto cleanup;
		}
		else
		{
			goto cleanup;
		}
	}
	else
	{
		goto cleanup;
	}

	// The following line is only needed if you need to print out guid
	//
	hr = StringFromCLSID(pInfo->ProviderGuid, &pStringGuid);
	if (FAILED(hr))
	{
		wprintf(L"StringFromCLSID(ProviderGuid) failed with 0x%x\n", hr);
		status = hr;
		goto cleanup;
	}
	CoTaskMemFree(pStringGuid);


	pStringGuid = NULL;

	if (!IsEqualGUID(pInfo->EventGuid, GUID_NULL))
	{
		hr = StringFromCLSID(pInfo->EventGuid, &pStringGuid);
		if (FAILED(hr))
		{
			wprintf(L"StringFromCLSID(EventGuid) failed with 0x%x\n", hr);
			status = hr;
			goto cleanup;
		}

		wprintf(L"\nEvent GUID: %s\n", pStringGuid);
		CoTaskMemFree(pStringGuid);
		pStringGuid = NULL;
	}


	if (DecodingSourceXMLFile == pInfo->DecodingSource)
	{
		wprintf(L"Event ID: %hu\n", pInfo->EventDescriptor.Id);
	}

	wprintf(L"Version: %d\n", pInfo->EventDescriptor.Version);

	if (pInfo->ChannelNameOffset > 0)
	{
		wprintf(L"Channel name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->ChannelNameOffset));
	}

	if (pInfo->LevelNameOffset > 0)
	{
		wprintf(L"Level name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->LevelNameOffset));
	}
	else
	{
		wprintf(L"Level: %hu\n", pInfo->EventDescriptor.Level);
	}

	if (DecodingSourceXMLFile == pInfo->DecodingSource)
	{
		if (pInfo->OpcodeNameOffset > 0)
		{
			wprintf(L"Opcode name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->OpcodeNameOffset));
		}
	}
	else
	{
		wprintf(L"Type: %hu\n", pInfo->EventDescriptor.Opcode);
	}

	if (DecodingSourceXMLFile == pInfo->DecodingSource)
	{
		if (pInfo->TaskNameOffset > 0)
		{
			wprintf(L"Task name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->TaskNameOffset));
		}
	}
	else
	{
		wprintf(L"Task: %hu\n", pInfo->EventDescriptor.Task);
	}

	wprintf(L"Keyword mask: 0x%I64x\n", pInfo->EventDescriptor.Keyword);
	if (pInfo->KeywordsNameOffset)
	{
		LPWSTR pKeyword = (LPWSTR)((PBYTE)(pInfo)+pInfo->KeywordsNameOffset);

		for (; *pKeyword != 0; pKeyword += (wcslen(pKeyword) + 1))
			wprintf(L"  Keyword name: %s\n", pKeyword);
	}

	if (pInfo->EventMessageOffset > 0)
	{
		wprintf(L"Event message: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->EventMessageOffset));
	}

	if (pInfo->ActivityIDNameOffset > 0)
	{
		wprintf(L"Activity ID name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->ActivityIDNameOffset));
		if (lstrcmpW(L"HcsRpc_CreateSystem_Start", (LPWSTR)((PBYTE)(pInfo)+pInfo->ActivityIDNameOffset)) == 0)
		{
			wprintf(L"pInfo->EventDescriptor : event id = %d op_code=%d\n", pInfo->EventDescriptor.Id, pInfo->EventDescriptor.Opcode);
			wprintf(L"processing HcsRpc_CreateSystem_Start event\n");
			wprintf(L"Timestamp =  %llu\n", pEvent->EventHeader.TimeStamp.QuadPart - g_hnsFirstEventTraceStartTime);
		}
	}

	if (pInfo->RelatedActivityIDNameOffset > 0)
	{
		wprintf(L"Related activity ID name: %s\n", (LPWSTR)((PBYTE)(pInfo)+pInfo->RelatedActivityIDNameOffset));
	}

	wprintf(L"Number of top-level properties: %lu\n", pInfo->TopLevelPropertyCount);

	wprintf(L"Total number of properties: %lu\n", pInfo->PropertyCount);

	// Print the metadata for all the top-level properties. Metadata for all the 
	// top-level properties come before structure member properties in the 
	// property information array.

	if (pInfo->TopLevelPropertyCount > 0)
	{
		wprintf(L"\nThe following are the user data properties defined for this event:\n");

		for (USHORT i = 0; i < pInfo->TopLevelPropertyCount; i++)
		{
			status = PrintPropertyMetadata(pInfo, i, 0);
			if (ERROR_SUCCESS != status)
			{
				wprintf(L"Printing metadata for top-level properties failed.\n");
				goto cleanup;
			}
		}
	}
	else
	{
		wprintf(L"\nThe event does not define any user data properties.\n");
	}

cleanup:

	if (pInfo)
	{
		free(pInfo);
	}

	if (ERROR_SUCCESS != status)
	{
		CloseTrace(g_hTrace);
	}
}



DWORD GetEventInformation(PEVENT_RECORD pEvent, PTRACE_EVENT_INFO & pInfo)
{
	DWORD status = ERROR_SUCCESS;
	DWORD BufferSize = 0;

	// Retrieve the required buffer size for the event metadata.

	status = TdhGetEventInformation(pEvent, 0, NULL, pInfo, &BufferSize);

	if (ERROR_INSUFFICIENT_BUFFER == status)
	{
		pInfo = (TRACE_EVENT_INFO*)malloc(BufferSize);
		if (pInfo == NULL)
		{
			wprintf(L"Failed to allocate memory for event info (size=%lu).\n", BufferSize);
			status = ERROR_OUTOFMEMORY;
			goto cleanup;
		}

		// Retrieve the event metadata.

		status = TdhGetEventInformation(pEvent, 0, NULL, pInfo, &BufferSize);
	}

	if (ERROR_SUCCESS != status)
	{
		//wprintf(L"TdhGetEventInformation failed with 0x%x.\n", status);
	}

cleanup:

	return status;
}


// Print the metadata for each property.

DWORD PrintPropertyMetadata(TRACE_EVENT_INFO* pinfo, DWORD i, USHORT indent)
{
	DWORD status = ERROR_SUCCESS;
	DWORD j = 0;
	DWORD lastMember = 0;  // Last member of a structure

						   // Print property name.

	wprintf(L"%*s%s", indent, L"", (LPWSTR)((PBYTE)(pinfo)+pinfo->EventPropertyInfoArray[i].NameOffset));


	// If the property is an array, the property can define the array size or it can
	// point to another property whose value defines the array size. The PropertyParamCount
	// flag tells you where the array size is defined.

	if ((pinfo->EventPropertyInfoArray[i].Flags & PropertyParamCount) == PropertyParamCount)
	{
		j = pinfo->EventPropertyInfoArray[i].countPropertyIndex;
		wprintf(L" (array size is defined by %s)", (LPWSTR)((PBYTE)(pinfo)+pinfo->EventPropertyInfoArray[j].NameOffset));
	}
	else
	{
		if (pinfo->EventPropertyInfoArray[i].count > 1)
			wprintf(L" (array size is %lu)", pinfo->EventPropertyInfoArray[i].count);
	}


	// If the property is a buffer, the property can define the buffer size or it can
	// point to another property whose value defines the buffer size. The PropertyParamLength
	// flag tells you where the buffer size is defined.

	if ((pinfo->EventPropertyInfoArray[i].Flags & PropertyParamLength) == PropertyParamLength)
	{
		j = pinfo->EventPropertyInfoArray[i].lengthPropertyIndex;
		wprintf(L" (size is defined by %s)", (LPWSTR)((PBYTE)(pinfo)+pinfo->EventPropertyInfoArray[j].NameOffset));
	}
	else
	{
		// Variable length properties such as structures and some strings do not have
		// length definitions.

		if (pinfo->EventPropertyInfoArray[i].length > 0)
			wprintf(L" (size is %lu bytes)", pinfo->EventPropertyInfoArray[i].length);
		else
			wprintf(L" (size  is unknown)");
	}

	wprintf(L"\n");


	// If the property is a structure, print the members of the structure.

	if ((pinfo->EventPropertyInfoArray[i].Flags & PropertyStruct) == PropertyStruct)
	{
		wprintf(L"%*s(The property is a structure and has the following %hu members:)\n", 4, L"",
			pinfo->EventPropertyInfoArray[i].structType.NumOfStructMembers);

		lastMember = pinfo->EventPropertyInfoArray[i].structType.StructStartIndex +
			pinfo->EventPropertyInfoArray[i].structType.NumOfStructMembers;

		for (j = pinfo->EventPropertyInfoArray[i].structType.StructStartIndex; j < lastMember; j++)
		{
			PrintPropertyMetadata(pinfo, j, 4);
		}
	}
	else
	{
		// You can use InType to determine the data type of the member and OutType
		// to determine the output format of the data.

		if (pinfo->EventPropertyInfoArray[i].nonStructType.MapNameOffset)
		{
			// You can pass the name to the TdhGetEventMapInformation function to 
			// retrieve metadata about the value map.
			wprintf(L"%*s(Map attribute name is %s)\n", indent, L"",
				(PWCHAR)((PBYTE)(pinfo)+pinfo->EventPropertyInfoArray[i].nonStructType.MapNameOffset));
		}
	}

	return status;
}

