using System;
using System.Collections;
using System.Reflection;

namespace Serialize
{
	struct SerializeAttribute : Attribute, IOnFieldInit
	{
		public String Rename = null;
		public String Default = null;
		public String DefaultValue = null;

		public String NumberFormat = null;

		public bool Serialize => _flag != .Skip;
		public bool Optional => _flag == .Optional || _hasDefault;
		public bool Flatten => _flag == .Flatten;

		private bool _hasDefault => Default != null || DefaultValue != null;

		private Flag _flag;

		enum Flag
		{
			None,
			Skip,
			Optional,
			Flatten
		}

		public this(Flag flag = .None)
		{
			_flag = flag;
		}

		[Comptime]
		public void OnFieldInit(FieldInfo fieldInfo, Self* prev)
		{
			let type = fieldInfo.FieldType;

			if (Flatten)
			{
				let generic = type as SpecializedGenericType;
				if (generic == null ||
					generic.UnspecializedType != typeof(Dictionary<>))
				{
					Runtime.FatalError("Flat field needs to be of type Dictionary<>");
				}

				if (Rename != null)
					Runtime.FatalError("Cannot rename a flat field");
			}

			if (NumberFormat != null && !IsNumber(type))
			{
				let generic = type as SpecializedGenericType;
				if (generic != null && generic.UnspecializedType == typeof(List<>))
				{
					if (!IsNumber(generic.GetGenericArg(0)))
						Runtime.FatalError("List must have numeric values to use NumberFormat");
				}
				else if (generic != null && generic.UnspecializedType == typeof(Dictionary<>))
				{
					if (!IsNumber(generic.GetGenericArg(1)))
						Runtime.FatalError("Dictionary must have numeric values to use NumberFormat");
				}
				else
					Runtime.FatalError(scope $"Field type is not a number: {!IsNumber(generic.GetGenericArg(0))}");
			}

			bool IsNumber(Type type) => type.IsInteger || type.IsFloatingPoint;
		}
	}
}